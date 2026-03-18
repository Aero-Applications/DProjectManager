import std.file;
import std.stdio;
import std.algorithm : endsWith;
import std.conv : to;
import std.path;

version (OSX) version = DPM_Apple;
version (iOS) version = DPM_Apple;
version (TVOS) version = DPM_Apple;
version (WatchOS) version = DPM_Apple;
version (VisionOS) version = DPM_Apple;

//****************************** Client Functions ******************************
/*

    How To Use:

    Step 1, Create a d project file:
        I like to call my file 'project.d' but the name may be what ever you like.
    Step 2, Configure your project:
        Create a main function in your new file: "void main(string[] args) {}",
        and inside the main function import DProjectManager: "import DProjectManager;"
        then create a 'ProjectDefinition': "ProjectDefinition definition;"
        you can now adjust the settings of your project definition. see the 'ProjectDefinition' struct below to see all the avaliable configurations
        for instance: "
            definition.projectName = "DApp";
            app.sources = SourceSet(directories: ["src"], estimatedFileCountInDirectories: 10);
        "
    Step 3, Call the build function:
        Last but not least you may now choose the appropriate function for your project.
        There are two: 'build(definition: definition)' and 'buildAndRun(definition: definition)'
        If you are building a library, you want 'build' since you can't run a library.
        And if you want an executable, though you may still use 'build' if you do not want to run it, 'buildAndRun' is avaliable to build and then run it.
        your code may look something like this: 
        """
            void main(string[] args) {
                import DProjectManager;

                ProjectDefinition app;
                app.projectName = "DApp";
                app.dCompiler = DCompilers.DMD;
                app.outputType = OutputType.Executable;
                app.sources = SourceSet(directories: ["src"], estimatedFileCountInDirectories: 10);
                app.executableDirectory = "bin";
                app.intermediateDirectory = "obj";
                app.configurations = [
                    "Debug" : Configuration(optimizationLevel: OptimizationLevel.OptimizationOff, versionIdentifiers: ["Debug"]),
                    "Release" : Configuration(optimizationLevel: OptimizationLevel.Optimization3, versionIdentifiers: ["Release"])
                ];
                app.activeConfiguration = "Debug";

                DProjectManager.buildAndRun(definition: app);
            }
        """
    Step 4, Run the build system:
        Make sure you have built the DProjectManager console application,
        and have it installed within your environment variables so that the console can find it.
        Then type this command: 
            'DProjectManager project.d'
        This assumes that the console is open in the project directory otherwise the command would look like this:
            'DProjectManager path/to/project.d'
*/
//****************************** Client Functions ******************************

// returns true when build succedded, and fase when build failed.
// this function calls the 'build()' function and then calls the executable to run if build succeds.
// - Parameters:
//  - definition: the structure containing all the neccessary information to generate the compiler command for building
bool buildAndRun(ProjectDefinition definition) => buildAndRun(&definition);

// returns true when build succedded, and fase when build failed.
// this function builds the project using the information provided in the 'ProjectDefinition' structure to generate a compiler command that will build the project
// - Parameters:
//  - definition: the structure containing all the neccessary information to generate the compiler command for building
bool build (ProjectDefinition definition) => build(&definition);

//****************************** Structs ******************************

private struct FileLastCompileData {
    ulong size;
    ulong hash;

    this(string filename) {
        auto data = std.file.readText(filename);
        this.size = data.length;
        this.hash = data.hashOf;
    }
};

// Info regarding the last build of a particular project.
// this information will be stored in the intermediateDirectory of the ProjectDefinition that the Project belongs to.
struct DProjectManagerLastRunInfo {
    bool debugMode = false;
    bool debugModeLastCompile = false;
    // Used to not recompile files that do not need to be recompiled.
    // We check each file's last modified date and compare it with this
    long timeAtLastCompile = 0;
    // A map from file paths to data about the file last time it was compiled. 
    // If, in fact, it ever was
    // this is useful in case the file was modified then the modification was undone
    FileLastCompileData[string] fileDataByName;

    public void load(string directory) {
        string path = directory ~ "/LastBuildInfo.txt";

        if (path.exists()) {

            size_t pos = 0;

            ubyte[] bytes = cast(ubyte[]) read(path);
            if (bytes.length == 0)
                return;

            ref T get(T)() {
                T* result = (cast(T*) &bytes[pos]);
                pos += T.sizeof;
                return *result;
            }
            this.debugModeLastCompile = get!(bool)();{
                get!(char)(); // read new line
            }
            this.timeAtLastCompile = get!(ulong)(); {
                get!(char)(); // read new line
            }

            while (pos < bytes.length) {
                size_t filenameSize = get!size_t();
                string filename;
                filename.reserve(filenameSize);

                foreach (size_t i; 0..filenameSize) {
                    char character = get!char();
                    filename ~= character;
                }
                get!(char)(); // read new line

                FileLastCompileData data = get!FileLastCompileData(); {
                    this.fileDataByName[filename] = data;
                }
            }
        }

        debug info("On Load this.fileDataByName == '" ~ to!string(fileDataByName) ~ "'");

    }
    public void save(string directory) {
        import std.datetime.systime : SysTime, Clock;
        import core.stdc.stdio;
        import std.path : absolutePath;

        string path = directory ~ "/LastBuildInfo.txt";

        debug info("Saving build info: '" ~ to!string(fileDataByName) ~ "' to " ~ path);

        if (!path.exists()) {
            info("Directory: '" ~ path ~ "'. did not exist. Creating...");
            mkdirRecurse(directory);
            std.file.write(path, "");
        }

        FILE* file = fopen(absolutePath(path).ptr, "w");

        if (!file) {
            error("Failed to open file: '" ~ absolutePath(path) ~ "'.");
            return;
        }

        void put(T)(T t) {
            fwrite(cast(void*) &t, char.sizeof, t.sizeof, file);
            fwrite(cast(void*) "\n".ptr, char.sizeof, 1, file);
        }

        put!bool(this.debugMode);
        put!long(Clock.currTime().stdTime);

        foreach (filename, data; this.fileDataByName) {
            enum MAX_FILENAME_LENGTH = 260;
            enum DATA_SIZE = data.sizeof;
            enum BYTE_SIZE_TOTAL = size_t.sizeof + MAX_FILENAME_LENGTH + DATA_SIZE + 1;

            byte[BYTE_SIZE_TOTAL] bytes;
            uint bytesUsed = 0;

            void write(T)(T* object) {
                enum OBJECT_SIZE = (*object).sizeof;
                byte* objectData = cast(byte*) object;
                
                foreach (int i; 0..OBJECT_SIZE) {
                    bytes[bytesUsed++] = objectData[i];
                }
            }

            size_t nameLength = filename.length; {
                write(&nameLength);
            }
            foreach (char character; filename) {
                bytes[bytesUsed++] = cast(byte) character;
            }
            write(&data);

            fwrite(cast(void*) bytes.ptr, byte.sizeof, bytesUsed, file);
            fwrite(cast(void*) "\n".ptr, byte.sizeof, 1, file);
        }

        fclose(file);

        debug info("On Save this.fileDataByName == '" ~ to!string(fileDataByName) ~ "'");

    }

    // retreives the last modification data of the file at 'filePath' on the computer
    // and compares it with DProjectManagerLastRunInfo.timeAtLastCompile to see if it has been changed since them;
    // Parameters: 
    //  - filePath: the path to the file relative to the working directory
    public bool doesDFileNeedToBeRecompiled(string filePath) {    
        return this.doesFileNeedToBeRecompiledInternal(filePath);
    }
    public bool doesCppFileNeedToBeRecompiled(ProjectDefinition* definition, string filePath) {
        return this.doesFileNeedToBeRecompiledInternal(definition.cppCompiler.preprocess(filePath, definition.intermediateDirectory));
    }
    private bool doesFileNeedToBeRecompiledInternal(string filePath) {
        if (this.debugMode != this.debugModeLastCompile)
            return true;
        long nanosecondsSinceModified = long.max;
        try {
            nanosecondsSinceModified = timeLastModified(filePath).stdTime;
        } catch (Exception exception) {
            error("file " ~ filePath ~ " cannot be verified in doesDFileNeedToBeRecompiled()" ~ exception.message());
        }
        if (nanosecondsSinceModified > this.timeAtLastCompile) {
            FileLastCompileData* data = filePath in this.fileDataByName;
            if (data) {
                debug info("Data for file " ~ filePath ~ " is: " ~ to!string(*data));
                auto contents = std.file.readText(filePath);
                if (data.size != contents.length) {
                    debug info("Size of file " ~ filePath ~ " is now " ~ to!string(contents.length) ~ " (was " ~ to!string(data.size) ~ "), recompiling");
                    data.size = contents.length;
                    return true;
                } else {
                    auto hash = contents.hashOf;
                    if (data.hash != hash) {
                        debug info("hash of file " ~ filePath ~ " is now " ~ to!string(hash) ~ " (was " ~ to!string(data.hash) ~ "), recompiling");
                        data.hash = hash;
                        return true;
                    } else {
                        return false;
                    }
                }
            } else {
                this.fileDataByName[filePath] = FileLastCompileData(filePath);
                return true;
            }
        } else {
            return false;
        }
    }
}

enum Architecture {
    Undefined,
    x86_64,
    x86,
    Arm64,
    Arm
}

// a structure that simply holds the command line programs and flags to be executed in the command line.
struct Compiler {
    // the name of the compiler. usually an executable file somewhere on your pc. For Instance: ('dmd', 'gdc', 'ldc', 'clang', 'msvc', 'gcc').
    // note that the compiler must be installed on the user's system before using, DProjectManager cannot install it.
    string compilerName;
    // call this function to set the output directory
    // into the compiler command
    void function(ref string[] command, string outputLocation) setOutputLocation;
    // call this function to set the output directory for object files
    // into the compiler command
    void function(ref string[] command, string outputLocation) setObjectFileLocation;
    // the flag that will be used to notify the compiler to define a "version identifier" in D, or a Compiler Defined Macro in C/C++
    void function(ref string[] command, string define) define;
    // adds the library and the link flag to the command
    void function(ref string[] command, string libraryFile) linkLibrary;
    // the flag to search for files to import in D, and include paths in C/C++.
    void function(ref string[] command, string searchDirectory) addImportSearchPath;
    // used to specify the architecture to build for.
    void function(ref string[] command, Architecture architecture) specifyArchitecture;
    // returns the name of the preprocessed file generated by the compiler
    // this function returns the filename parameter if no preprocessing is possible for the given language
    string function(string filename, string outputDirectory) preprocess;
    // an array of 4 possible string arrays.
    // in some compilers, optimization levels arn't a thing.
    // in such compilers a number of arguments can optimize the code, like allowing inlining, or notifiying the compiler that you want release mode, ect...
    // the best way to index into the array is not 0, 1, 2, ect..., but actually with the 'OptimizationLevel' enum.
    // that is why in the 'Configuration' struct there is an 'OptimizationLevel' field
    string[][4] optimizationLevels;
    // an array of 3 possible strings.
    // there is no outputTypeFlag in the compiler itself, there are different flags for each type.
    // the best way to index into the array is not 0, 1, 2, ect..., but actually with the 'OutputType' enum.
    // the 'OutputType' of a Project is defined in the 'ProjectDefinition' struct.
    string[3] outputTypeFlags;
    // what flag is used to tell this compiler that we don't want to link together the executable, just compile into object files.
    string compileOnlyFlag;

    bool isAvailiable() {
        import std.process : executeShell;
        // On Windows, use `where`.
        version (Windows) {
            auto shellCmd = `where ` ~ this.compilerName;
        } else {
            auto shellCmd = `command -v ` ~ this.compilerName; 
        }

        try {
            // Execute the command and capture the result.
            // On success, the exit status will be 0.
            auto result = executeShell(shellCmd);
            return result.status == 0;
        } catch (Exception e) {
            // Handle potential exceptions during execution
            return false;
        }
    }
}
// an enum containing 'Compiler' objects that are bound to a d compiler.
// remember that this structure just holds the commands to be executed in the command line, nothing more.
// note that the compiler must be installed on the user's system before using, DProjectManager cannot install it.
enum DCompilers : Compiler {
    DMD = Compiler(
        compilerName: "dmd", 
        setOutputLocation: (ref string[] command, string outputLocation) {
	        command ~= "-of=" ~ outputLocation;
        },
        setObjectFileLocation: (ref string[] command, string outputLocation) {
            command ~= "-od=" ~ outputLocation;
        }, 
        define: (ref string[] command, string define) {
             command ~= "-version=" ~ define;
        },
        linkLibrary: (ref string[] command, string libraryFile) {
           command ~= "-L=" ~ libraryFile;
        },
        addImportSearchPath: (ref string[] command, string searchDirectory) {
            command ~= "-I=" ~ searchDirectory;
        },
        specifyArchitecture: (ref string[] command, Architecture architecture) {
            switch (architecture) {
                case Architecture.x86_64: 
                    command ~= "-m64";
                    break;
                case Architecture.x86: 
                    command ~= "-m32";
                    break;
                case Architecture.Arm64: 
                    error("Arm architectures are not supported by DMD, compiling for x86_64 instead");
                    command ~= "-m64";
                    break;
                case Architecture.Arm: 
                    error("Arm architectures are not supported by DMD, compiling for x86 instead");
                    command ~= "-m32";
                    break;
                default:
                    break;
            }
        },
        preprocess: (string filename, string outputDirectory) {
            return filename;
        },
        optimizationLevels: [
            /*OptimizationLevel.OptimizationOff :*/ [], 
            /*OptimizationLevel.Optimization1 :*/ ["-O", "-release"], 
            /*OptimizationLevel.Optimization2 :*/ ["-O", "-release", "-boundscheck=off"], 
            /*OptimizationLevel.Optimization3 :*/ ["-O", "-release", "-inline", "-boundscheck=off"]
        ],
        outputTypeFlags: [
            "",
            "-lib",
            "-shared"
        ],
        compileOnlyFlag: "-c"
    ),
    LDC = Compiler(
        compilerName: "ldc2", 
        setOutputLocation: (ref string[] command, string outputLocation) {
	    command ~= "-of=" ~ outputLocation;
        },
        setObjectFileLocation: (ref string[] command, string outputLocation) {
            command ~= "-od=" ~ outputLocation;
        }, 
        define: (ref string[] command, string define) {
             command ~= "--d-version=" ~ define;
        },
        linkLibrary: (ref string[] command, string libraryFile) {
           command ~= "-L=" ~ libraryFile;
        },
        addImportSearchPath: (ref string[] command, string searchDirectory) {
            command ~= "-I=" ~ searchDirectory;
        },
        specifyArchitecture: (ref string[] command, Architecture architecture) {
            switch (architecture) {
                case Architecture.x86_64: 
                    command ~= ["-march", "x86-64"];
                    break;
                case Architecture.x86: 
                    command ~= ["-march", "i386"];
                    break;
                case Architecture.Arm64: 
                    command ~= ["-march", "arm64"];
                    break;
                case Architecture.Arm: 
                    command ~= ["-march", "arm"];
                    break;
                default:
                    break;
            }
        },
        preprocess: (string filename, string outputDirectory) {
            return filename;
        },
        optimizationLevels: [
            /*OptimizationLevel.OptimizationOff :*/ [], 
            /*OptimizationLevel.Optimization1 :*/ ["-O1", "-release"], 
            /*OptimizationLevel.Optimization2 :*/ ["-O2", "-release", "-boundscheck=off"], 
            /*OptimizationLevel.Optimization3 :*/ ["-O3", "-release", "-boundscheck=off"]
        ],
        outputTypeFlags: [
            "",
            "-lib",
            "-shared"
        ],
        compileOnlyFlag: "-c"
    )
    //GDC - planned for the future.
}

string GetCppPreprocessedPath(string filename, string intermediateDirectory){
    return intermediateDirectory ~ baseName(filename)[ 0 .. $ - 3] ~ "i";
}
// an enum containing 'Compiler' objects that are bound to a d compiler.
// remember that this structure just holds the commands to be executed in the command line, nothing more.
// note that the compiler must be installed on the user's system before using, DProjectManager cannot install it.
enum CppCompilers : Compiler {
    Clang = Compiler(
        compilerName: "clang++", 
        setOutputLocation: (ref string[] command, string outputLocation) {
            command ~= "-o"; command ~= outputLocation;
        },
        setObjectFileLocation: (ref string[] command, string outputLocation) {
            command ~= "-o"; command ~= outputLocation ~ "out";
        }, 
        define: (ref string[] command, string define) {
             command ~= "--define-macro=" ~ define;
        },
        linkLibrary: (ref string[] command, string libraryFile) {
           command ~= "-l:" ~ libraryFile;
        },
        addImportSearchPath: (ref string[] command, string searchDirectory) {
            command ~= "-I" ~ searchDirectory;
        },
        specifyArchitecture: (ref string[] command, Architecture architecture) {
            switch (architecture) {
                case Architecture.x86_64: 
                    command ~= ["-arch", "x86_64"];
                    break;
                case Architecture.x86: 
                    command ~= ["-arch", "i386"];
                    break;
                case Architecture.Arm64: 
                    command ~= ["-arch", "arm64"];
                    break;
                case Architecture.Arm: 
                    command ~= ["-arch", "arm"];
                    break;
                default:
                    break;
            }
        },
        preprocess: (string filename, string outputDirectory) {
            import std.process : execute;
            string preprocessedFilePath = GetCppPreprocessedPath(filename, outputDirectory);
            execute(["clang++", "-E", filename, "-o", preprocessedFilePath]);
            return preprocessedFilePath;
        },
        optimizationLevels: [
            /*OptimizationLevel.OptimizationOff :*/ [], 
            /*OptimizationLevel.Optimization1 :*/ ["-O1", "-ffast-math"], 
            /*OptimizationLevel.Optimization2 :*/ ["-O2", "-ffast-math"], 
            /*OptimizationLevel.Optimization3 :*/ ["-O3", "-ffast-math"]
        ],
        outputTypeFlags: [
            "",
            "-lib",
            "-shared"
        ],
        compileOnlyFlag: "-c"
    )
}
// how optimized do you want the compiler to optimize your code.
// this can cause compilation to take longer
// note there is no garentee that Optimization1-3 are any different from each other, that is compiler dependant
enum OptimizationLevel : byte {
    OptimizationOff = 0,
    Optimization1 = 1,
    Optimization2 = 2,
    Optimization3 = 3
}
// when building code, developers often want to write code that performs checks to discover when things go wrong.
// but when the application is shipped to the client that code might slow down the execution of the program.
// to combat this you can create configurations and put them into the configurations map inside the ProjectDefinition struct.
struct Configuration {
    // how optimized do you want the compiler to optimize your code.
    // this can cause compilation to take longer so when writing the code, other wise known as 'Debug Configuration' you can leave this as OptimizationLevel.OptimizationOff;
    // note there is no garentee that Optimization1-3 are any different from each other, that is compiler dependant
    OptimizationLevel optimizationLevel = OptimizationLevel.Optimization3;
    // version identifiers that will be set when code is compiled
    // for example: 'configuration.versionIdentifiers = ["Professional", "Debug"]'
    // then in your code: 'version(Professional) { /* code here will be compiled */ } else version (Community) { /* this code won't be compiled*/ }'
    // and: 'version(Debug) { /* code here will be compiled */ } else version (Release) { /* this code won't be compiled*/ }'
    string[] versionIdentifiers = [];
}
// what kind of file do you want to generate.
// Executable: an executable file with a main function that can be run (.exe, etc...).
// StaticLibrary: some compiled code that can be linked into an Executable at compile time (.lib, .a, etc...).
// DynamicLibrary: some compiled code that can be linked into an Executable at run time (.dll, .dylib, .so, etc...)..
enum OutputType : byte {
    Executable = 0, StaticLibrary = 1, DynamicLibrary = 2
}

struct CopyCommand {
    // the path to the file to copy.
    string from;
    // the path to the destination, this includes the name of the new file.
    string to;
}

struct SourceSet {  
    string[] files = [];
    string[] directories = [];
    int estimatedFileCount;

    // - Parameter files: a list of file names to compile
    this(string[] files){
        this.files = files;
        this.estimatedFileCount = cast(uint) files.length;
    }
    // - Parameters:
    //   - files: a list of file names to compile
    //   - directories: a list of directories full of files to compile
    //   - estimatedFileCountInDirectories: a guess as to how many files are in the directories signaled by the directories array
    this(string[] files, string[] directories, int estimatedFileCountInDirectories) {
        this.files = files;
        this.directories = directories;
        this.estimatedFileCount = cast(uint) files.length + estimatedFileCountInDirectories;
    }
    // - Parameters:
    //   - directories: a list of directories full of files to compile
    //   - estimatedFileCountInDirectories: a guess as to how many files are in the directories signaled by the directories array
    this(string[] directories, int estimatedFileCountInDirectories) {
        this.directories = directories;
        this.estimatedFileCount = cast(int) estimatedFileCountInDirectories;
    }
};

struct Dependency { 
    private enum Type {
        ByDefinition,
        ByDPMFile,
        ByDubProject,
        Framework,
        None
    }
    private struct DPMDependencyFromFile {
        string filename;
        string dependencyName;
    }
    private struct DubDependencyInfo {
        string projectDirectory;
    }
    private struct FrameworkInfo {
        string name;
    }
    private union {
        ProjectDefinition m_Definition;
        DPMDependencyFromFile m_DPMDependencyFile;
        DubDependencyInfo m_DubDependencyInfo;
        FrameworkInfo m_FrameworkInfo;
    }
    private Type m_Type;

    string[] linkables;
    string[] importables;

    this(string[] linkables, string[] importables) {
        m_Type = Type.None;
        this.linkables = linkables;
        this.importables = importables;
    }

    this(ProjectDefinition definition) {
        m_Type = Type.ByDefinition;
        m_Definition = definition;
        assert(definition.outputType != OutputType.Executable, "Dependency.this(ProjectDefinition definition): 'definition.outputType' was 'OutputType.Executable', Cannot link an Executable into any other project.");
    }
    this(string filename, string dependencyName) {
        m_Type = Type.ByDPMFile;
        m_DPMDependencyFile = DPMDependencyFromFile();
        m_DPMDependencyFile.filename = filename;
        m_DPMDependencyFile.dependencyName = dependencyName;
    }

    static Dependency Framework(string name) {
        version (DPM_Apple) {
            Dependency dependency;
            dependency.m_Type = Type.Framework;
            dependency.m_FrameworkInfo.name = name;
            return dependency;
        }
    }

    static Dependency FromDub(string pathToDubProject, string[] linkables, string[] importables) {
        Dependency dependency;
        dependency.m_Type = Type.ByDubProject;
        if (!isDir(pathToDubProject)) {
            pathToDubProject = dirName(pathToDubProject);
        }
        if (!pathToDubProject.endsWith('/')) {
            pathToDubProject ~= '/';
        }

        foreach (ref string linkable; linkables) {
            if (!exists(linkable))
                linkable = pathToDubProject ~ linkable;
            assert(exists(linkable), "The file passed in the 'linkables' array in Dependency.FromDub() does not exist.\n\t- Path: " ~ linkable);
            assert(!isDir(linkable), "The file passed in the 'linkable' array in Dependency.FromDub() must be a linkable library file\n\t- Instead:\n\t\t- found directory: " ~ linkable);
        }
        foreach (ref string importable; importables) {
            if (!exists(importable))
                importable = pathToDubProject ~ importable;
        }

        dependency.m_DubDependencyInfo = DubDependencyInfo();
        dependency.m_DubDependencyInfo.projectDirectory = pathToDubProject;
        dependency.linkables = linkables;
        dependency.importables = importables;
        return dependency;
    }

    string toString() {
        switch (m_Type) {
            case Type.None:
                return linkables.stringof;
            case Type.ByDefinition:
                return m_Definition.projectName;
            case Type.ByDPMFile:
                return m_DPMDependencyFile.dependencyName;
            case Type.ByDubProject:
                return baseName(m_DubDependencyInfo.projectDirectory);
            case Type.Framework:
                return m_FrameworkInfo.name;
            default:
                assert(false, "toString() not implemented for new dependency type");
        }
    }

    bool buildDependency(ProjectDefinition* definition) {
        switch (m_Type) {
            case Type.None:
                return true;
            case Type.ByDefinition:
                return this.buildProjectDefinition();
            case Type.ByDPMFile:
                return this.buildExternalDependancy();
            case Type.ByDubProject:
                return this.buildDubDependency();
            case Type.Framework:
                return this.applyFramework(&definition.dCompiler);
            default:
                assert(false, "buildDependency() not implemented for new dependency type");
        }
    }

    private bool buildProjectDefinition() {
        prepareProjectDirectoriesAndEnsureCorrectness(&m_Definition);

        linkables ~= getExecutableDirectory(&m_Definition); 
        foreach(Dependency dependency; m_Definition.dependencies) {
            foreach(string library; dependency.linkables) {
                linkables ~= absolutePath(library);
            }
        }
        importables ~= m_Definition.sources.directories;
        importables ~= m_Definition.sources.files;

        return build(definition: &m_Definition);
    }

    private bool buildExternalDependancy() {
        string filename = m_DPMDependencyFile.filename;
        string dependencyName = m_DPMDependencyFile.dependencyName;

        import std.process : environment, execute, wait; {
            immutable string D_PROJECT_MANAGER_PATH = environment.get("DProjectManagerPath");
            auto output = execute(
                args: [D_PROJECT_MANAGER_PATH, filename],
            );
            write(output.output);
            if (output.status != 0)
                return false;
        }

        loadDependencyFile(
            filename: dirName(filename)  ~ "/.DProjectManager/" ~ dependencyName ~ '/' ~ dependencyName ~ ".txt",
            outLinkables: &this.linkables,
            outImports: &this.importables
        );

        return true;
    }

    private bool buildDubDependency() {
        import std.process : execute, wait; {
            writeln("\n************************************ Building ***********************************");
            scope(exit)
                writeln("************************************ Completed ***********************************");
            auto output = execute(
                args: ["dub"],
                workDir: m_DubDependencyInfo.projectDirectory
            );
            write(output.output);
            return true;
        }
    }
    private bool applyFramework(Compiler* compiler) {
        linkables ~= "-framework";
        linkables ~= m_FrameworkInfo.name;
        return true;
    }

    bool cleanDependency() {
        switch (m_Type) {
            case Type.ByDefinition:
                return this.cleanProjectDefinition();
            case Type.ByDPMFile:
                return this.cleanExternalDependancy();
            default:
                assert(false, "Unknown Dependency.Type in Dependency.build();");
        }
    }

    private bool cleanProjectDefinition() {
        clean(definition: &m_Definition);
        return true;
    }

    private bool cleanExternalDependancy() {
        string filename = m_DPMDependencyFile.filename;
        string dependencyName = m_DPMDependencyFile.dependencyName;
        import std.process : environment, execute, wait;
        immutable string D_PROJECT_MANAGER_PATH = environment.get("DProjectManagerPath");
        auto output = execute(
            args: [D_PROJECT_MANAGER_PATH, filename, "-clean"],
        );
        return output.status == 0;
    }
};

// describes how you want your project build
// most items have sensible defaults, you just need to include your sources
struct ProjectDefinition {
    // Which Compiler to use to compile d code. 
    // you can make your own 'Compiler()' objects too, if you have an unsupported compiler on your machine
    // all you have to do in your file is fill out all the neccessary information in the Compiler constructor
    Compiler dCompiler = DCompilers.DMD;
    // Which Compiler to use to compile c++ code. 
    // you can make your own 'Compiler()' objects too, if you have an unsupported compiler on your machine
    // all you have to do in your file is fill out all the neccessary information in the Compiler constructor
    Compiler cppCompiler = CppCompilers.Clang;
    // tells whether to build an executable, static library, or dynamic library
    OutputType outputType = OutputType.Executable;
    // allows you to specify a specific architecture to build for. 
    // this is recommended because it will ensure all compilers build for the same architecture, instead of each choosing it's own
    Architecture architecture = Architecture.Undefined;
    // a map of configuration names to configuration structures containing information about them
    Configuration[string] configurations = ["debug": Configuration(OptimizationLevel.OptimizationOff, ["Debug"]), "release": Configuration(OptimizationLevel.Optimization3, ["Release"])];
    // the name of the Configuration to use in the config map
    string activeConfiguration = "debug";
    // the name of the executable or library file
    string projectName = "myapp";
    // Command line arguments passed to the program when it is run
    string[] programArguments = [];
    // where to put executable files
    // Note: Library files will not be placed the same as executables, like: 'executableLocation/name.lib' but rather like: 'objectFilesLocation/executableLocation/name.lib'
    string executableDirectory = "bin";
    // where to put object and library files
    string intermediateDirectory = "obj";
    // specific file paths to compile relative to where you run this code from in the terminal
    // or directories to search for source files in relative to where you run this code from in the terminal
    SourceSet sources;
    // files to search for that can be imported import 
    string[] importDirectories;
    // version identifiers that will be set when code is compiled
    // for example: 'definition.versionIdentifiers = ["Professional"]'
    // then in your code: 'version(Professional) { /* code here will be compiled */ } else version (Community) { /* this code won't be compiled*/ }'
    string[] versionIdentifiers;
    // an array of files to copy.
    // this array is of CopyCommands which are structures defined above which simply contain a path to the file to copy and a path to the destination
    CopyCommand[] copyFiles;
    // version numbers that will be set when code is compiled
    // for example: 'definition.versionNumbers = [3001]'
    // then in your code: 'version(3001) { /* code here will be compiled */ } else version (2510) { /* this code won't be compiled*/ }'
    int[] versionNumbers;
    // Other DProjectManager ProjectDefinitions that you declare, and build into libraries, can be linked by adding them into this array
    // Note: if a 'ProjectDefinition' in the array is an executable then it will still be built, but of course not linked.
    // Note: if a 'ProjectDefinition' in the array is an dynamic library then it will be added to the copy files array.
    Dependency[] dependencies;
    // other arguments that will be passed to the compiler
    string[] otherCompilerArguments;
    // other arguments that will be passed to the linker
    string[] otherLinkerArguments;
}

//****************************** Helper Functions ******************************

// writes: "[Info]: ", then your message to the console.
// Parameters: 
//  - message: the message to pass to the 'writeln' function.
private void info(T)(T message) {
    writeln("[Info]: " ~ message);
}
// writes: "[Warn]: ", then your message to the console.
// Parameters: 
//  - message: the message to pass to the 'writeln' function.
private void warn(T)(T message) {
    writeln("[Warn]: " ~ message);
}
// writes: "[Error]: ", then your message to the console.
// Parameters: 
//  - message: the message to pass to the 'writeln' function.
private void error(T)(T message) {
    writeln("[Error]: " ~ message);
}

private void prepareProjectDirectoriesAndEnsureCorrectness(ProjectDefinition* definition) {
    if (!definition.executableDirectory.endsWith('/'))
        definition.executableDirectory ~= '/';
    if (!definition.intermediateDirectory.endsWith('/'))
        definition.intermediateDirectory ~= '/';

    mkdirRecurse(definition.executableDirectory);
    mkdirRecurse(definition.intermediateDirectory);    
}

private ulong guesstimateCompileCommandLength(ProjectDefinition* definition, string[] optimizationFlags) {
    return 5 + definition.importDirectories.length + optimizationFlags.length + definition.versionIdentifiers.length + 
               definition.versionNumbers.length + definition.otherCompilerArguments.length + definition.sources.estimatedFileCount;
}

// returns the number of files compiled. 0 is technically a failure
private int compile(ProjectDefinition* definition, DProjectManagerLastRunInfo* buildInfo) {    
    info("Preparing to compile project " ~ definition.projectName);

    string[] dSources = [];
    string[] cppSources = [];

    if (!loadSourceFiles(definition, buildInfo, &dSources, &cppSources))
        return -1;

    if (!compileD(definition, &dSources))
        return -1;
    
    if (!compileCpp(definition, &cppSources))
        return -1;

    int compiledFiles = cast(int) (dSources.length + cppSources.length);

    info("Finished compiling project " ~ definition.projectName);

    debug {
        info("compiled " ~ to!string(compiledFiles) ~ " files");
    }

    return compiledFiles;
}

private bool loadSourceFiles(ProjectDefinition* definition, DProjectManagerLastRunInfo* buildInfo, string[]* dSources, string[]* cppSources) {
    import std.parallelism : parallel;

    foreach(string source; definition.sources.files.parallel()) {
        if (!buildInfo.doesDFileNeedToBeRecompiled(source)) {
            continue;
        }
        // fixme
        (*dSources) ~= source;
    }

    foreach (string directory; definition.sources.directories.parallel()) {
        if (directory.exists()){
            auto entries = dirEntries(directory, SpanMode.depth);
            foreach (string name; entries){
                if (!name.endsWith(".d") && !name.endsWith(".c")) {
                    if (name.endsWith(".cpp")) {
                        if (buildInfo.doesCppFileNeedToBeRecompiled(definition, name)){
                            (*cppSources) ~= name;
                        } else {
                            debug info("file " ~ name ~ " does not need to be recompiled.");
                        }
                    }
                    continue;
                }
                if (!buildInfo.doesDFileNeedToBeRecompiled(name)) {
                    debug info("file " ~ name ~ " does not need to be recompiled.");
                    continue;
                }
                (*dSources) ~= name;
            }
        } else {
            error("The source directory: '" ~ directory ~ "' is not a real directory. Please check " ~ definition.projectName ~ "'s sources.directories array and remove any non-existent directories from the list like this: 'myProjectDefinition.sources.directories = [\"myProject/src\"]', or create the missing directory. Aborting compilation.");
            return false;
        }
    }
    return true;

}

private bool compileD(ProjectDefinition* definition, string[]* dSources) {
    import std.process : execute;

    if (dSources.length == 0)
        return true;

    Compiler* dCompiler = &definition.dCompiler;

    string[] optimizationFlags = dCompiler.optimizationLevels[definition.configurations[definition.activeConfiguration].optimizationLevel];

    string[] command; {
        command.reserve(guesstimateCompileCommandLength(definition, optimizationFlags));
    }

    command ~= dCompiler.compilerName;

    command ~= *dSources;

    defineVersions(dCompiler, command, definition);

    dCompiler.specifyArchitecture(command, definition.architecture);
    dCompiler.setObjectFileLocation(command, definition.intermediateDirectory); 
    command ~= definition.dCompiler.compileOnlyFlag;
    
    addImportDirectories: {
        foreach (string srcDirectory; definition.sources.directories)
            dCompiler.addImportSearchPath(command, srcDirectory);
        foreach (string directory; definition.importDirectories)
            dCompiler.addImportSearchPath(command, directory);
        foreach (const ref Dependency dependency; definition.dependencies) {
            foreach (string directory; dependency.importables) {
                dCompiler.addImportSearchPath(command, directory);
            }
        }
    }

    optimization: {
        if (optimizationFlags.length != 0)
            command ~= optimizationFlags;
    }

    ExecuteCompiler: {
        command ~= definition.otherCompilerArguments;     
        auto compilerOutput = execute(command);
        if (compilerOutput.status != 0) {
            write("Compilation failed:\n Command used: ");
            foreach (string word; command) 
                write(word ~ ' ');
            writeln('\n' ~ compilerOutput.output);
            return false;
        } else {
            debug {
                info("Compilation succedded!\n Command used: ");
                foreach (string word; command) 
                    write(word ~ ' ');
                writeln('\n' ~ compilerOutput.output);
            }
        }
    }

    return true;
}

private bool compileCpp(ProjectDefinition* definition, string[]* cppSources) {
    import std.process : execute;

    if (cppSources.length == 0)
        return true;

    definition.dependencies ~= Dependency(["-lstdc++"], []);

    Compiler* cppCompiler = &definition.cppCompiler;

    string[] optimizationFlags = cppCompiler.optimizationLevels[definition.configurations[definition.activeConfiguration].optimizationLevel];

    string[] command; {
        command.reserve(guesstimateCompileCommandLength(definition, optimizationFlags));
    }

    command ~= cppCompiler.compilerName;

    command ~= GetCppPreprocessedPath((*cppSources)[0], definition.intermediateDirectory);
    
    cppCompiler.specifyArchitecture(command, definition.architecture);
    defineVersions(cppCompiler, command, definition);

    command ~= cppCompiler.compileOnlyFlag;
    
    addImportDirectories: {
        foreach (string directory; definition.importDirectories)
            cppCompiler.addImportSearchPath(command, directory);
    }

    optimization: {
        if (optimizationFlags.length != 0)
            command ~= optimizationFlags;
    }

    ExecuteCompiler: {
        command ~= definition.otherCompilerArguments;   
        ulong i = 1;
        while (true) {
            ulong commandLengthBeforeOutput = command.length;
            cppCompiler.setOutputLocation(command, command[1][0 .. $ - 1] ~ 'o'); 
            ulong commandLengthAfterOutput = command.length;

            auto compilerOutput = execute(command);
            if (compilerOutput.status != 0) {
                write("Compilation failed:\n Command used: ");
                foreach (string word; command) 
                    write(word ~ ' ');
                writeln('\n' ~ compilerOutput.output);
                return false;
            } else {
                debug {
                    info("Compilation succedded!\n Command used: ");
                    foreach (string word; command) 
                        write(word ~ ' ');
                    writeln('\n' ~ compilerOutput.output);
                }
            }
            if (i < cppSources.length) {
                import std.algorithm.mutation : remove;
                command[1] = GetCppPreprocessedPath((*cppSources)[i++], definition.intermediateDirectory);
                command.remove(commandLengthBeforeOutput, commandLengthAfterOutput);
            } else 
                break;
       };
    }

    return true;
}

private ulong guesstimateLinkCommandLength(ProjectDefinition* definition) {
    return 5 + definition.dependencies.length + definition.otherLinkerArguments.length + definition.sources.estimatedFileCount;
}

private bool link(ProjectDefinition* definition, DProjectManagerLastRunInfo* buildInfo) {
    import std.process;

    info("Preparing to link project " ~ definition.projectName);

    Compiler* dCompiler = &definition.dCompiler;

    string[] command;{
        command.reserve(guesstimateLinkCommandLength(definition));
    }

    command ~= dCompiler.compilerName;
    
    dCompiler.specifyArchitecture(command, definition.architecture);
    dCompiler.setOutputLocation(command, getExecutableDirectory(definition));
    
    linkLibraries(command, definition);

    outputType: {
        string outputTypeFlag = dCompiler.outputTypeFlags[definition.outputType];
        if (outputTypeFlag.length != 0)
            command ~= outputTypeFlag;
    }

    auto entries = dirEntries(definition.intermediateDirectory, SpanMode.shallow);
    foreach (string name; entries) {
        if (name.endsWith(".o"))
            command ~= name;
    }

    command ~= definition.otherLinkerArguments;

    auto compilerOutput = execute(command);
    if (compilerOutput.status != 0) {
        write("Linking failed:\n Command used: ");
        foreach (string word; command) 
            write(word ~ ' ');
        writeln('\n' ~ compilerOutput.output);
        buildInfo.timeAtLastCompile = 0; // this will force a recompile of every source file.
        buildInfo.save(".DProjectManager/" ~ definition.projectName);
        return false;
    } else {
        debug {
            info("Linking succedded!\n Command used: ");
                    foreach (string word; command) 
                write(word ~ ' ');
            writeln('\n' ~ compilerOutput.output);
        }
    }

    info("Finished linking project " ~ definition.projectName);

    return true;
}

private bool build (ProjectDefinition* definition) {
    if (!buildDependencies(definition: definition))
        return false;
    writeln("\n************************************ Building ***********************************");
    scope(exit)
        writeln("************************************ Completed ***********************************");

    prepareProjectDirectoriesAndEnsureCorrectness(definition: definition);

    DProjectManagerLastRunInfo buildInfo;
    buildInfo.load(".DProjectManager/" ~ definition.projectName);

    int compiledFiles = compile(definition, &buildInfo);
    if (compiledFiles > -1){
        if (link(definition, &buildInfo)) { 
            copyFiles: {
                foreach (ref copyCommand; definition.copyFiles) {
                    try {
                        debug info("Copying '" ~ copyCommand.from ~ "' to " ~ copyCommand.to);
                        copy(from: copyCommand.from, to: copyCommand.to);
                    } catch (Exception e) {
                        error("Failed to copy: " ~ copyCommand.from ~ ", to: " ~ copyCommand.to);
                        return false;
                    }
                }
            }
            saveDependancyFile(definition: definition);
            buildInfo.save(".DProjectManager/" ~ definition.projectName);
            return true;
        }
    }
    return false;
}

private bool buildAndRun(ProjectDefinition* definition) {
    import std.process;

    if (!build(definition))
        return false;

    if (definition.outputType != OutputType.Executable) {
        string type = (definition.outputType == OutputType.StaticLibrary ? "Static Library" : "Dynamic Library");
        warn("BuildAndRun called on '" ~ type ~ "'. You cannot run a '" ~ type ~ "'. Please call build() instead.");
        return true;
    }

    info("Launching app: " ~ definition.projectName);

    writeln("\n************************************ Program ***********************************");
    scope(exit) 
        writeln("************************************ Completed ***********************************");

    auto appName = absolutePath(definition.executableDirectory ~ definition.projectName ~ getExtension(definition.outputType));
    auto app = spawnProcess(
        args: [appName] ~ definition.programArguments,
		stdin: stdin,
		stdout: stdout, 
		stderr: stderr,
		workDir: std.path.dirName(appName)
    ).wait();
    return true;
}

private bool buildDependencies(ProjectDefinition* definition) {
    foreach (ref Dependency dependency; definition.dependencies) {
        if (!dependency.buildDependency(definition)) {
            error("Failed to build dependency: '" ~ dependency.toString() ~ "' for project: '" ~ definition.projectName ~ ".'");
            return false;
        }
    }
    return true;
}
// given a project, it takes the project's compiler and defines macros/versions for each element in the project's 'versionIdentifiers' field,
// and each number in the project's 'versionNumbers' field, and every identifier in the project's active configuration's 'versionIdentifiers' field.
// Parameters: 
//  - definition: the project to calculate Version Identifiers flags for
private void defineVersions(Compiler* compiler, ref string[] command, ProjectDefinition* definition) {
    foreach (string identifier; definition.versionIdentifiers) {
        compiler.define(command, identifier);
    }
    foreach (int identifier; definition.versionNumbers) {
        compiler.define(command, to!string(identifier));
    }
    foreach (string identifier; definition.configurations[definition.activeConfiguration].versionIdentifiers) {
        compiler.define(command, identifier);
    }
}
// adds link flags for each library to the command
// - Parameter:
//     - command: a reference to the string[] that will be executed to link the program together.
//.    - definition: the details of the project we are linking into.
private void linkLibraries(ref string[] command, ProjectDefinition* definition) {
    if (definition.outputType == OutputType.Executable) {
        foreach (const ref Dependency dependency; definition.dependencies) {
            foreach(string linkable; dependency.linkables) {
                definition.dCompiler.linkLibrary(command, linkable);
            }
        }
    }
}

private string getExecutableDirectory(ProjectDefinition* definition) {
    string path = definition.executableDirectory;
    string name = (definition.projectName ~ getExtension(definition.outputType));
    return path ~ name;
}

private string getExtension(OutputType type) {
    version (Windows) {
        switch (type) {
            case OutputType.StaticLibrary: return ".lib";
            case OutputType.DynamicLibrary: return ".dll";
            default: return ".exe";
        }
    } else version (OSX) {
        switch (type) {
            case OutputType.StaticLibrary: return ".a";
            case OutputType.DynamicLibrary: return ".dylib";
            default: return ".out";
        }
    } else {
        switch (type) {
            case OutputType.StaticLibrary: return ".a";
            case OutputType.DynamicLibrary: return ".so";
            default: return ".out";
        }
    }
}

void clean(ProjectDefinition* definition) {
    import std.file : rmdirRecurse;
    std.file.rmdirRecurse(definition.executableDirectory);
    std.file.rmdirRecurse(definition.intermediateDirectory);
}

void loadDependencyFile(string filename, string[]* outLinkables, string[]* outImports) {
    if (!std.file.exists(filename)) {
        error("Failed to load dependency file '" ~ absolutePath(filename) ~ "' because it does not exist.");
        return;
    }

    auto file = File(filename);

    enum Mode {
        None,
        Linkables,
        Imports
    }

    Mode mode = Mode.None;

    foreach (line;  file.byLine()) {
        final switch (mode) {
            case Mode.None:
                if (line == "Linkables") 
                    mode = Mode.Linkables;
                break;
            case Mode.Linkables:
                if (line == "Imports") {
                    mode = Mode.Imports;
                } else {
                    (*outLinkables) ~= line.idup;
                }
                break;
            case Mode.Imports:
                (*outImports) ~= line.idup;
                break;
        }
    }
}

void saveDependancyFile(ProjectDefinition* definition) {
    if (definition.outputType == OutputType.Executable)
        return;
    string path = ".DProjectManager/" ~ definition.projectName ~ '/';
    if (!path.exists())
        mkdirRecurse(path);
    auto filename = path ~ definition.projectName ~ ".txt";
    auto file = File(filename, "w");

    file.writeln("Linkables");
    file.writeln(absolutePath(getExecutableDirectory(definition)));

    foreach (const ref Dependency dependency; definition.dependencies) {
        foreach(string linkable; dependency.linkables) {
            if (std.file.exists(linkable)) {
                file.writeln(absolutePath(linkable));
            } else {
                file.writeln(linkable);
            }
        }
    }

    file.writeln("Imports");
    foreach(string source; definition.sources.files) {
        if (source.endsWith(".d")) {
            file.writeln(absolutePath(source));
        }
    }

    foreach (string directory; definition.sources.directories) {
        if (directory.exists()){
            auto entries = dirEntries(directory, SpanMode.depth);
            foreach (string name; entries){
                if (isDir(name)) {
                    file.writeln(absolutePath(dirName(name)));
                }                 
            }
        }
    }

}
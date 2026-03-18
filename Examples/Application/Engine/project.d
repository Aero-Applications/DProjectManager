import DProjectManager;

void main(string[] arguments) {
    string buildConfiguration = "Debug";         

    ProjectDefinition engine; {
        engine.projectName = "Engine";
        engine.dCompiler = DCompilers.DMD;
        engine.cppCompiler = CppCompilers.Clang; 
        engine.outputType = OutputType.StaticLibrary;
        engine.sources = SourceSet(directories: ["src"], estimatedFileCountInDirectories: 10);
        engine.executableDirectory = "bin";
        engine.intermediateDirectory = "obj";
        engine.configurations = [
            "Debug" : Configuration(optimizationLevel: OptimizationLevel.OptimizationOff, versionIdentifiers: ["Debug"]),
            "PreRelease" : Configuration(optimizationLevel: OptimizationLevel.Optimization3, versionIdentifiers: ["PreRelease"]),
            "Release" : Configuration(optimizationLevel: OptimizationLevel.Optimization3, versionIdentifiers: ["Release"])
        ]; 
        engine.dependencies = [
            Dependency.FromDub("../RandomDubDependencyB", ["librandom-dub-dependency-b.a"], ["source"]), 
            Dependency(  
                ["libraries/GLFW/lib/Macos/x86/libglfw3.a"], 
                ["libraries/GLFW/include"]
            ),
            Dependency.Framework("Cocoa"),    
            Dependency.Framework("CoreFoundation"),
            Dependency.Framework("OpenGL"), 
            Dependency.Framework("IOKit")
        ]; 
        engine.activeConfiguration = buildConfiguration; 
    }
    build(definition: engine);  
}  
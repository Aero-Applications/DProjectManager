// dmd main.d DProjectManager.d -od=obj -of=bin/DProjectManager

import DProjectManager;
import std.stdio : print = writeln, printRaw = write, stdin, stdout, stderr;
import std.process;
import std.file;
import std.path;
import std.array : replace;

void main(string[] arguments) {	
	immutable string THIS_EXECUTABLE_PATH = std.file.thisExePath();
	immutable string THIS_EXECUTABLE_DIR = std.path.dirName(THIS_EXECUTABLE_PATH) ~ '/';
	immutable string D_PROJECT_MANAGER_SOURCE_FILE = THIS_EXECUTABLE_DIR ~ "../DProjectManager.d";

	Compiler compiler = getCompiler();
	if (arguments.length <= 1) {
		print("[DProjectManager][Error]: No project file was provided");
		print(".             [Expected]: DProjectManager <arguments to DProjectManager> ./project.d <arguments to program>");
		return;
	}

	string scriptPath = "";
	bool debugMode = false;

	int programArgumentsIndex = parseArguments(&arguments, &scriptPath, &debugMode);

	string outputLocation = replace(std.path.dirName(scriptPath).stripExtension(), "/../", "_");{
		outputLocation = replace(outputLocation, "/./", "_");
		outputLocation = replace(outputLocation, '/', '_');
		outputLocation = replace(outputLocation, '\\', '_');
		outputLocation = dirName(THIS_EXECUTABLE_DIR) ~ "/projects/" ~ outputLocation[1..$];
	}

	DProjectManagerLastRunInfo buildInfo;{
    	buildInfo.load(outputLocation ~ '/');
		buildInfo.debugMode = debugMode;
	}
	string executableName = outputLocation ~ '/' ~ scriptPath.baseName().stripExtension();
	if (buildInfo.doesDFileNeedToBeRecompiled(scriptPath)) {
		print("Recompiling Project file.");
		if (!compileProjectFile(&compiler, D_PROJECT_MANAGER_SOURCE_FILE, scriptPath, executableName, outputLocation, debugMode)) {
			return;
		}
	}

	buildInfo.save(outputLocation ~ '/');

	auto program = spawnProcess(
		args: getProgramAndArguments(executableName, arguments, programArgumentsIndex),
		env: ["DProjectManagerPath" : THIS_EXECUTABLE_PATH],
		stdin: stdin,
		stdout: stdout, 
		stderr: stderr,
		workDir: std.path.dirName(scriptPath)
	);
}

int parseArguments(string[]* arguments, string* scriptPath, bool* debugMode) {
	bool foundFile = false;
	
	int i = 1;
	for (; i < arguments.length; i++) {
		string argument = (*arguments)[i];

		if (std.file.exists(argument)) {
			if (std.file.isFile(argument)) {
				*scriptPath = std.path.absolutePath(argument);
				foundFile = true;
				i++;
				break;
			}
		} else {
			if (argument == "-debug") {
				*debugMode = true;
			}
		}
	}

	if (!foundFile) {
		print("[DProjectManager][Error]: No project file was provided");
		print(".             [Expected]: DProjectManager <arguments to DProjectManager> ./project.d <arguments to program>");
		return cast(int) arguments.length;
	}

	return i;
}

string[] getProgramAndArguments(string executableName, string[] arguments, int programArgumentsIndex) {
	string[] programAndArgs = [std.path.absolutePath(executableName)]; {
		if (arguments.length >= programArgumentsIndex)
			programAndArgs ~= arguments[programArgumentsIndex..$];
	} 
	return programAndArgs;
}

bool compileProjectFile(Compiler* compiler, immutable string D_PROJECT_MANAGER_SOURCE_FILE, string scriptPath, string executableName, string outputLocation, bool debugMode) {
	string[] command = [compiler.compilerName, D_PROJECT_MANAGER_SOURCE_FILE, scriptPath]; {
		command.reserve(command.length + 2 + compiler.optimizationLevels.length);
		if (debugMode)
			command ~= "--d-debug";
		compiler.setOutputLocation(command, executableName);
		compiler.setObjectFileLocation(command, outputLocation);
		command ~= compiler.optimizationLevels[3];
	}

	auto output = execute(command);{
		if (output.status != 0) {
			print("[DProjectManager][Error]: Compilation failed:\n Command used: ");
			foreach (string word; command) 
				printRaw(word ~ ' ');
			print('\n' ~ output.output);
			return false;
		} else {
			debug {
				print("[DProjectManager]: Compilation succedded!\n Command used: ");
				foreach (string word; command) 
					printRaw(word ~ ' ');
				print('\n' ~ output.output);
			}
			return true;
		}
	}
}

Compiler getCompiler() {
	Compiler compiler = DCompilers.LDC;
	if (!compiler.isAvailiable()) {
		print("[DProjectManager]: Failed to detect the ldc2 compiler, checking dmd...");
		compiler = DCompilers.DMD;
		if (!compiler.isAvailiable()) {
			print("[DProjectManager]: Failed to detect the dmd compiler, gdc is not yet supported, aborting...");
			throw new Exception("Failed to detect supported compiler");
		}
	}
	return compiler;
}
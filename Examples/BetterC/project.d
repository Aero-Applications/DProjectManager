void main(string[] arguments) {
    import DProjectManager;
 
    string activeConfiguration = "Debug";    

    ProjectDefinition game; {    
        game.projectName = "BetterC";      
        game.dCompiler = DCompilers.DMD;   
        game.outputType = OutputType.Executable;  
        game.sources = SourceSet(directories: ["src"], estimatedFileCountInDirectories: 10);
        game.executableDirectory = "bin";
        game.intermediateDirectory = "obj";  
        game.configurations = [ 
            "Debug" : Configuration(optimizationLevel: OptimizationLevel.OptimizationOff, versionIdentifiers: ["Debug"]),
            "PreRelease" : Configuration(optimizationLevel: OptimizationLevel.Optimization3, versionIdentifiers: ["PreRelease"]),
            "Release" : Configuration(optimizationLevel: OptimizationLevel.Optimization3, versionIdentifiers: ["Release"])
        ]; 
        game.otherCompilerArguments = [
            "-betterC"
        ];
        game.activeConfiguration = activeConfiguration;     
    }   

    for (int i = 1; i < arguments.length; i++) {  
        string argument = arguments[i];
        if (argument == "-clean") {
            DProjectManager.clean(definition: &game);    
            return;
        } else {
            throw new Exception("Unknown argument: " ~ argument ~ '\n');
        }
    }
      
    DProjectManager.buildAndRun(definition: game);
}
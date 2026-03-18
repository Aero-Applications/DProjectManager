extern(C++) {
    void printCpp();
}

void main(string[] arguments) {
    import Engine.Core.Application;
    
    import std.stdio : print = writeln, printf = writefln, write;

    if (arguments.length > 1) {
        print("Argument 1: ", arguments[1]);
    }

    version(Debug) {
        print("Started Game in Debug Mode");
    } else version (Release) {
        print("Started Game in Release Mode");
    } else {
        print("Started Game in Unknown Configuration");
    }

    {
        import RandomDependencyA;
        write("RandomDubDependencyA.printA(): ");
        RandomDependencyA.printA();
    }
    {
        printCpp();
    }

    Application app;

    app.run(); 

    print("Program terminated with exit code 0"); 
}
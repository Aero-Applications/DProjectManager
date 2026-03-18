module Engine.Core.Application;

struct Application {
    bool running = true;

    void run() {
        import std.stdio : print = writeln, write;
        
        import GLFW3;

        GLFW3.glfwInit();
        scope(exit) GLFW3.glfwTerminate();

        {
            import RandomDependencyB;
            write("RandomDubDependencyB.printB(): ");
            RandomDependencyB.printB();
        }

        print("Application started.");
        scope(exit) print("Application terminated.");

        GLFW3.GLFWwindow* window = GLFW3.glfwCreateWindow(640, 480, "D Glfw Window", null, null);

        if (!window) {
            print("[Error]: Application.run(): Failed to create window");
            return;
        }

        while (!GLFW3.glfwWindowShouldClose(window)) {
            GLFW3.glfwPollEvents();
        }
    }
}
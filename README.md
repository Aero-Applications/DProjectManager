# DProjectManager

Welcome to the DProjectManager repository. This project is a proof of concept build system for the D programming language and C++, it is not actively being maintained. I don't know about you, but for me, I love a build system where the scripts are written in the target language, (or similar in the case of C++). Build systems like these allow

- flexability,
- autocomplete,
- conditions without the hastle of learning how to represent your condition in the build system's choosen data format (i.e. json, toml, yaml, cmake, ect...)),

  Aside from wanting every language to adopt this way of writing build systems, (like Swift and Zig have), I thought I would try and build one myself in my free time.

# How To Build

DProjectManager itself was designed to be a simple build, just two files. There is a build command at the top of './DProjectManager/main.d' to build it with dmd, and you're good to go.

# How to Use

Using DProjectManager is just as simple as building it. All you need to do is type this command: 

    DProjectManager/bin/DProjectManager -debug ./path/to/project.d

and your good to go.

# Platforms

The DProjectManager has only been tested on MacOS, but should run anywhere with little to no modification.

# Known Issues

When a D file's interface changes (Like a function is removed), it's dependents are not notified which leads to linking errors. This is what makes this fun side project a 'proof of concept.' I just simply don't have the time to add a system for:

* manually parsing a d file's import statements, creating a list of dependants for each D file,
* manually parsing a d file's declarations, creating an binary interface representation for each D file
* comparing a newly generated binary interface with the old one,
* and at long last: recompiling all files in the list of dependants, (noting that there must be a system to not rebuild a D file twice, in case it was built because it was changed, and then it is discovered that dependencies changed causing it to be built a second time in one run)

# Conclusion

If you are using D to build projects, it is probably best to stick with Dub unless you have time to completly overhaul this project's recompilation checking system

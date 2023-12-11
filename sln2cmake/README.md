# From Visual Studio Solution to CMake

Recently I needed to convert an existing VS2019 solution to CMake, due to the consideration of CI auto build.

I didn't have much knowledge on CMake. Should I learn its basic by reading some tutorials first, or use some tool to do the conversion?

There are 2 choices.

1. Learn CMake first, then write the `CMikeLists.txt` file from scratch.  
2. Use a tool to convert `sln` to `CMikeLists.txt`, then modify the output.  

I am inclined to learn the new things from the examples, so I decided to have a go with [CMake Converter](https://cmakeconverter.readthedocs.io/en/latest/index.html). It certainly gave me a very good start point. At least it added the long list of source files, as the creators of CMake themselves advise not to use globbing. See the discussion at [Is it better to specify source files with GLOB or each file individually in CMake?](https://stackoverflow.com/questions/1027247/is-it-better-to-specify-source-files-with-glob-or-each-file-individually-in-cmak).

It turned out that I needed to change many things on the generated `CMikeLists.txt` to make the new build work. Here are something I learned.

## Dependency
My solution contains 15 projects. Some projects depend on other projects.  Assume `B` depends on `A`, and `C` depends `A` and `B`.

I thought this order in the parent `CMikeLists.txt` would do the job. 

```
add_subdirectory(A)
add_subdirectory(B) 
add_subdirectory(C)
```
Unfortunately not, we still need to configure the dependency in each `CMakeLists.txt` file. For instance, in project `C`

`add_dependencies(${PROJECT_NAME} A B)`


## RelWithDebInfo

Software may crash in some situation. Generally we generate `PDB` file as well as `exe` and `dll` file. This will make the life easier.

I can use this simple build type `RelWithDebInfo` to achieve this purpose. 

`cmake --build build64 --config RelWithDebInfo`

## Code Sign

The generated result on `signtool` by [CMake Converter](https://cmakeconverter.readthedocs.io/en/latest/index.html)  was not working.

```
################################################################################
# Post build events
################################################################################
add_custom_command_if(
    TARGET ${PROJECT_NAME}
    POST_BUILD
    COMMANDS
    COMMAND              $<CONFIG:Release> signtool.exe sign /sha1 "4f29aa91faa9a6d514b5458070c9802d36e6c137" /td sha256 /fd sha256 /tr http://timestamp.comodoca.com /d "MyProject" /du "http://www.mycompany.com" $<SHELL_PATH:$<TARGET_FILE:${PROJECT_NAME}>>
    COMMAND $<CONFIG:WithSafeStickRelease> signtool.exe sign /sha1 "4f29aa91faa9a6d514b5458070c9802d36e6c137" /td sha256 /fd sha256 /tr http://timestamp.comodoca.com /d "MyProject" /du "http://www.mycompany.com" $<SHELL_PATH:$<TARGET_FILE:${PROJECT_NAME}>>
    COMMENT "Sign output"
)

```

I need to sign each sub project, so I defined a `macro` in the parent `CMakeLists.txt`,

```
set(SIGN_PARAMS /sha1 "4f29aa91faa9a6d514b5458070c9802d36e6c137" /fd SHA256 /t http://timestamp.sectigo.com /du "http://www.mycompany.com")

macro (set_code_sign description target)
    add_custom_command( TARGET ${target}
        POST_BUILD
        COMMAND signtool sign ${SIGN_PARAMS} /d ${description} $<TARGET_FILE:${target}>
        VERBATIM
    )
endmacro (set_code_sign)

```

Then just add this line in each sub project,

`set_code_sign("The description on this particular project" ${PROJECT_NAME})`

## Redundancy

I noticed many things in the generated `CMakeLists.txt` file were redundant, especially when you are going to use the default Compiler/Link Options.

Here are some examples we can simply remove them.

```
use_props(${PROJECT_NAME} "${CMAKE_CONFIGURATION_TYPES}" "${DEFAULT_CXX_PROPS}")
################################################################################
# Includes for CMake from *.props
################################################################################
if("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "x64")
    use_props(${PROJECT_NAME} Debug                "../x64/Debug/.conan/conanbuildinfo.cmake")
    use_props(${PROJECT_NAME} Release              "../x64/Release/.conan/conanbuildinfo.cmake")
endif()
```

```
source_file_compile_options(../Common/json_spirit/json_spirit_reader.cpp ${FILE_CL_OPTIONS})
if("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "Win32")
    string(CONCAT FILE_CL_OPTIONS
        "/Y-"
    )
elseif("${CMAKE_VS_PLATFORM_NAME}" STREQUAL "x64")
    string(CONCAT FILE_CL_OPTIONS
        "/Y-"
    )
endif()
```

## Resource Files

Somehow the `rc` files are missed in the generated `CMakeLists.txt`. I had to add it back myself.

```
set(ALL_FILES
    ${no_group_source_files}
    ${Headers}
    ${Sources}
    "MyProject.rc"
)
```

## MIDL

I had some COM Interfaces defined in `idl` file, `midl` is used to generated the corresponding C++ header files etc.

Finally I adopted the suggestion from [Invoke MIDL compiler from CMAKE](https://stackoverflow.com/questions/46878906/invoke-midl-compiler-from-cmake).

```
set(MIDL_OUTPUT
    ${CMAKE_CURRENT_BINARY_DIR}/MyCOMObj_i.h.h
    ${CMAKE_CURRENT_BINARY_DIR}/MyCOMObj_i.c
    ${CMAKE_CURRENT_BINARY_DIR}/MyCOMObj_p.c
)
set(MIDL_FILE
    ${CMAKE_CURRENT_LIST_DIR}/MyCOMObj.idl
)
add_custom_command(
    OUTPUT ${MIDL_OUTPUT}
    COMMAND midl /h MyCOMObj_i.h /iid MyCOMObj_i.c /proxy MyCOMObj_p.c ${MIDL_FILE}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${MIDL_FILE}
    MAIN_DEPENDENCY ${MIDL_FILE}
    VERBATIM
)
```

## Rename Output

By default, the output target will have the same name as `${PROJECT_NAME}`. In order to change it, use

`set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "EXENewName")`

See it at [How to set the executable name in CMake?](https://stackoverflow.com/questions/24395517/how-to-set-the-executable-name-in-cmake).

## WIN32
This tool [CMake Converter](https://cmakeconverter.readthedocs.io/en/latest/index.html) somehow didn't add `WIN32`. You might get some strange linking problem like this,

```
libboost_test_exec_monitor.lib(test_main.obj) : error LNK2001: unresolved external symbol "int __cdecl test_main(int,char * * const)" (?test_main@@YAHHQEAPEAD@Z) 
```

In this case, manually add back `WIN32`,

`add_executable(${PROJECT_NAME} WIN32 ${ALL_FILES})`

**NOTE:** Without `WIN32`, `cmake` generates a console project `Console (/SUBSYSTEM:CONSOLE)`, instead of `Windows (/SUBSYSTEM:WINDOWS)`. 
You can check it in VS, `Project | Properties | Linker | System | SubSystem`.

## CMake Variables

How can I refer to the header file generated by `midl`? I realized I needed to learn [CMake Variable Guidelines](https://jeremimucha.com/2021/02/cmake-variable-guidelines/).

`CMAKE_CURRENT_BINARY_DIR` is what I wanted.

In Visual Studio, it is `Additional Include Directories`, it can be done with the following line,

`target_include_directories(${PROJECT_NAME} PUBLIC ${CMAKE_CURRENT_BINARY_DIR})`


# References

The following tutorials suit me.

[CMake Tutorial: Basic Concepts and Building Your First Project](https://sternumiot.com/iot-blog/cmake-tutorial-basic-concepts-and-building-your-first-project/)  
[CMake Made Easy](https://www.ravbug.com/tutorials/cmake-easy/)  
[Effective Modern CMake](https://gist.github.com/mbinna/c61dbb39bca0e4fb7d1f73b0d66a4fd1)  
[Introduction to modern CMake for beginners](https://www.internalpointers.com/post/modern-cmake-beginner-introduction)


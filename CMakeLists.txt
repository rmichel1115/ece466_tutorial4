cmake_minimum_required(VERSION 3.10)
project(t4)

find_package(LLVM REQUIRED CONFIG)

include_directories(${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

# Map required LLVM components to libraries
llvm_map_components_to_libnames(llvm_libs analysis bitreader bitwriter support)

# Source files
add_executable(t4 main.cpp)

# Link against LLVM and Bison/Yacc (if needed)
target_link_libraries(t4 ${llvm_libs} y)

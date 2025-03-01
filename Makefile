  GNU nano 6.2                                   Makefile                                             .PHONY: all clean

LLVMCONFIG=llvm-config-19
CXX = clang++-19
CXXFLAGS = -g -Wall -Wno-deprecated-register \
           -Wno-unneeded-internal-declaration \
           -Wno-unused-function

all:
        flex -o expr.lex.cpp expr.lex
        bison -d -o expr.y.cpp expr.y
        $(CXX) $(CXXFLAGS) -c -o expr.lex.o expr.lex.cpp `$(LLVMCONFIG) --cppflags`
        $(CXX) $(CXXFLAGS) -c -o expr.y.o expr.y.cpp `$(LLVMCONFIG) --cppflags`
        $(CXX) $(CXXFLAGS) -o t4 expr.y.o expr.lex.o  `$(LLVMCONFIG) --ldflags --libs --system-libs`

tester:
        clang-19 -o tester tester.c main.bc

clean:
        rm -Rf t4 expr.lex.cpp expr.y.cpp expr.y.hpp *.o *~ expr.y.output

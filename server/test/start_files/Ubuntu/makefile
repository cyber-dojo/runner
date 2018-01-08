CXXFLAGS += -I. -std=c++14 -Wall -Wextra -Werror
CXXFLAGS += -fsanitize=undefined
CXXFLAGS += -fno-sanitize-recover=undefined
CXXFLAGS += -fno-omit-frame-pointer

# Currently ubuntu17.04 + clang++4.0 on Docker for Mac
# (but not Docker Toolbox for Max) gives warnings when
# the address sanitizer is enabled...
# <warning>
# AddressSanitizer failed to allocate 0xdfff0001000 (15392894357504) bytes at
# address 2008fff7000 (errno: 12)\n==25==ReserveShadowMemoryRange failed while
# trying to map 0xdfff0001000 bytes. Perhaps you're using ulimit -v
# </warning>
#CXXFLAGS += -fsanitize=address

HPP_FILES = $(wildcard *.hpp)
COMPILED_HPP_FILES = $(patsubst %.hpp,%.compiled_hpp,$(HPP_FILES))
CPP_FILES = $(wildcard *.cpp)

.PHONY: test.output
test.output: test makefile
	@./$<

test: makefile $(CPP_FILES) $(COMPILED_HPP_FILES)
	@$(CXX) $(CXXFLAGS) -O $(CPP_FILES) -o $@

# This rule ensures header files build in their own right.
# The quality of header files is important because header files
# are #included from other files and thus have a large span
# of influence (unlike .cpp files which are not #included)

%.compiled_hpp: %.hpp
	@$(CXX) -x c++ $(CXXFLAGS) -c -o $@ $<

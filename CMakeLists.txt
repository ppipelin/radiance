cmake_minimum_required(VERSION 3.24)

include(CheckCXXCompilerFlag)

project(radiance
	VERSION 1.0
	DESCRIPTION "Radiance chess engine"
	LANGUAGES CXX
)

add_executable(radiance)

set(SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)

set(SOURCES
	${SOURCE_DIR}/uci.cpp
	${SOURCE_DIR}/ucioption.cpp
	${SOURCE_DIR}/piece.cpp
	${SOURCE_DIR}/king.cpp
	${SOURCE_DIR}/queen.cpp
	${SOURCE_DIR}/rook.cpp
	${SOURCE_DIR}/bishop.cpp
	${SOURCE_DIR}/knight.cpp
	${SOURCE_DIR}/pawn.cpp
)

target_sources(radiance PRIVATE
	src/main.cpp
	${SOURCES}
)

set_target_properties(radiance PROPERTIES LINK_WHAT_YOU_USE TRUE)

# target_compile_options(radiance PRIVATE -W4 ${OpenMP_CXX_FLAGS})
if(MSVC)
	add_compile_options(/W4)

	check_cxx_compiler_flag("/LTCG" COMPILER_SUPPORTS_LTCG)
	check_cxx_compiler_flag("/GL" COMPILER_SUPPORTS_GL)
	check_cxx_compiler_flag("/Gv" COMPILER_SUPPORTS_Gv)
	check_cxx_compiler_flag("/arch:AVX2" COMPILER_SUPPORTS_AVX2)
	check_cxx_compiler_flag("/O2" COMPILER_SUPPORTS_O2)
	check_cxx_compiler_flag("/Ox" COMPILER_SUPPORTS_OX)
	check_cxx_compiler_flag("/Oy" COMPILER_SUPPORTS_OY)
	check_cxx_compiler_flag("/fp:fast" COMPILER_SUPPORTS_FPF)

	if(COMPILER_SUPPORTS_LTCG)
		add_compile_options("$<$<CONFIG:RELEASE>:/LTCG>")
	endif()

	if(COMPILER_SUPPORTS_GL)
		add_compile_options("$<$<CONFIG:RELEASE>:/GL>")
	endif()

	if(COMPILER_SUPPORTS_Gv)
		add_compile_options("$<$<CONFIG:RELEASE>:/Gv>")
	endif()

	if(COMPILER_SUPPORTS_AVX2)
		add_compile_options("$<$<CONFIG:RELEASE>:/arch:AVX2>")
	endif()

	if(COMPILER_SUPPORTS_O2)
		add_compile_options("$<$<CONFIG:RELEASE>:/O2>")
	endif()

	if(COMPILER_SUPPORTS_OX)
		add_compile_options("$<$<CONFIG:RELEASE>:/Ox>")
	endif()

	if(COMPILER_SUPPORTS_OY)
		add_compile_options("$<$<CONFIG:RELEASE>:/Oy>")
	endif()

	if(COMPILER_SUPPORTS_FPF)
		add_compile_options("$<$<CONFIG:RELEASE>:/fp:fast>")
	endif()

	target_compile_definitions(radiance PRIVATE NDEBUG _WIN32_WINNT=0x0A00)
else()
	# GCC and Clang specific options
	add_compile_options(-Wall -Wextra -Wpedantic -Wno-unknown-pragmas -Wno-ignored-qualifiers)

	check_cxx_compiler_flag("-Ofast" COMPILER_SUPPORTS_OFAST)
	check_cxx_compiler_flag("-flto" COMPILER_SUPPORTS_LTO)
	check_cxx_compiler_flag("-ftree-vectorize" COMPILER_SUPPORTS_TREE_VECTORIZE)
	check_cxx_compiler_flag("-funroll-loops" COMPILER_SUPPORTS_UNROLL_LOOPS)
	check_cxx_compiler_flag("-fstrict-aliasing" COMPILER_SUPPORTS_STRICT_ALIASING)
	check_cxx_compiler_flag("-fomit-frame-pointer" COMPILER_SUPPORTS_OMIT_FRAME_POINTER)
	check_cxx_compiler_flag("-fwhole-program" COMPILER_SUPPORTS_WHOLE_PROGRAM)

	check_cxx_compiler_flag("-mpopcnt" COMPILER_SUPPORTS_POPCNT)
	check_cxx_compiler_flag("-msse4.1" COMPILER_SUPPORTS_SSE41)
	check_cxx_compiler_flag("-msse4.2" COMPILER_SUPPORTS_SSE42)
	check_cxx_compiler_flag("-mbmi" COMPILER_SUPPORTS_BMI)
	check_cxx_compiler_flag("-mfma" COMPILER_SUPPORTS_FMA)
	check_cxx_compiler_flag("-mavx" COMPILER_SUPPORTS_AVX)
	check_cxx_compiler_flag("-mavx2" COMPILER_SUPPORTS_AVX2)
	check_cxx_compiler_flag("-mbmi2" COMPILER_SUPPORTS_BMI2)
	check_cxx_compiler_flag("-march=native" COMPILER_SUPPORTS_MARCH_NATIVE)
	check_cxx_compiler_flag("-mtune=native" COMPILER_SUPPORTS_MTUNE_NATIVE)

	if(COMPILER_SUPPORTS_OFAST)
		add_compile_options("$<$<CONFIG:RELEASE>:-Ofast>")
	endif()

	if(COMPILER_SUPPORTS_LTO)
		add_compile_options("$<$<CONFIG:RELEASE>:-flto>")
	endif()

	if(COMPILER_SUPPORTS_TREE_VECTORIZE)
		add_compile_options("$<$<CONFIG:RELEASE>:-ftree-vectorize>")
	endif()

	if(COMPILER_SUPPORTS_UNROLL_LOOPS)
		add_compile_options("$<$<CONFIG:RELEASE>:-funroll-loops>")
	endif()

	if(COMPILER_SUPPORTS_STRICT_ALIASING)
		add_compile_options("$<$<CONFIG:RELEASE>:-fstrict-aliasing>")
	endif()

	if(COMPILER_SUPPORTS_OMIT_FRAME_POINTER)
		add_compile_options("$<$<CONFIG:RELEASE>:-fomit-frame-pointer>")
	endif()

	if(COMPILER_SUPPORTS_WHOLE_PROGRAM)
		add_compile_options("$<$<CONFIG:RELEASE>:-fwhole-program>")
	endif()

	if(COMPILER_SUPPORTS_POPCNT)
		add_compile_options("$<$<CONFIG:RELEASE>:-mpopcnt>")
	endif()

	if(COMPILER_SUPPORTS_SSE41)
		add_compile_options("$<$<CONFIG:RELEASE>:-msse4.1>")
	endif()

	if(COMPILER_SUPPORTS_SSE42)
		add_compile_options("$<$<CONFIG:RELEASE>:-msse4.2>")
	endif()

	if(COMPILER_SUPPORTS_BMI)
		add_compile_options("$<$<CONFIG:RELEASE>:-mbmi>")
	endif()

	if(COMPILER_SUPPORTS_FMA)
		add_compile_options("$<$<CONFIG:RELEASE>:-mfma>")
	endif()

	if(COMPILER_SUPPORTS_AVX)
		add_compile_options("$<$<CONFIG:RELEASE>:-mavx>")
	endif()

	if(COMPILER_SUPPORTS_AVX2)
		add_compile_options("$<$<CONFIG:RELEASE>:-mavx2>")
	endif()

	if(COMPILER_SUPPORTS_BMI2)
		add_compile_options("$<$<CONFIG:RELEASE>:-mbmi2>")
	endif()

	if(COMPILER_SUPPORTS_MARCH_NATIVE)
		add_compile_options("$<$<CONFIG:RELEASE>:-march=native>")
	endif()

	if(COMPILER_SUPPORTS_MTUNE_NATIVE)
		add_compile_options("$<$<CONFIG:RELEASE>:-mtune=native>")
	endif()

	target_compile_definitions(radiance PRIVATE NDEBUG)
endif()

target_compile_features(radiance PRIVATE cxx_std_23)

target_include_directories(radiance PRIVATE
	${CMAKE_CURRENT_LIST_DIR}/include
)

# OMP
# find_package(OpenMP REQUIRED)

# Link libraries
# target_link_libraries(radiance PRIVATE ${OpenMP_CXX_FLAGS})

# Tests
if(CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
	include(CTest)
endif()

if(CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME AND BUILD_TESTING)
	add_subdirectory(test)
endif()

add_test(NAME perftStart COMMAND perftStart)
add_test(NAME perftKiwi COMMAND perftKiwi)
add_test(NAME bitboardMoves COMMAND bitboardMoves)

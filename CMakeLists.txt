cmake_minimum_required(VERSION 3.14)

project(radiance
	VERSION 1.0
	DESCRIPTION "Radiance chess engine"
	LANGUAGES CXX
)

add_executable(radiance)

set(SOURCES
	src/uci.cpp
	src/ucioption.cpp
	src/piece.cpp
	src/king.cpp
	src/queen.cpp
	src/rook.cpp
	src/bishop.cpp
	src/knight.cpp
	src/pawn.cpp
)

target_sources(radiance PRIVATE
	src/main.cpp
	${SOURCES}
)

# target_compile_options(radiance PRIVATE -W4 ${OpenMP_CXX_FLAGS})
target_compile_options(radiance PRIVATE -W4)

target_include_directories(radiance PRIVATE
	${CMAKE_CURRENT_LIST_DIR}/include
)

set(CMAKE_CXX_STANDARD 23)
target_compile_features(radiance PRIVATE cxx_std_23)

target_compile_definitions(radiance PRIVATE _WIN32_WINNT=0x0A00)

############ OMP
# find_package(OpenMP REQUIRED)

############ Link libraries
# target_link_libraries(radiance PRIVATE ${OpenMP_CXX_FLAGS})

############ Tests
enable_testing()

include_directories(
	${CMAKE_CURRENT_LIST_DIR}/include
)

add_executable(perftStart test/perftStart.cpp ${SOURCES})
add_executable(perftKiwi test/perftKiwi.cpp ${SOURCES})
add_executable(bitboardMoves test/bitboardMoves.cpp ${SOURCES})

# Define tests
add_test(NAME perftStart COMMAND perftStart)
add_test(NAME perftKiwi COMMAND perftKiwi)
add_test(NAME bitboardMoves COMMAND bitboardMoves)

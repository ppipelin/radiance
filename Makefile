.DEFAULT_GOAL := default

ifndef EXE
EXE=radiance
endif

ifneq ($(OS),Windows_NT)
MV=move .\zig-out\bin\radiance.exe $(EXE).exe
else
MV=mv ./zig-out/bin/radiance $(EXE)
endif

print-os:
	$(info OS = $(OS))

default:
	zig build --release=fast
	@$(MV)

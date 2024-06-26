all:
	odin build . -out:xy_audio.exe --debug

opti:
	odin build . -out:xy_audio.exe -o:speed

opti_max:	
	odin build . -out:xy_audio.exe -o:aggressive -microarch:native -no-bounds-check -disable-assert

clean:
	rm xy_audio.exe

run:
	./xy_audio.exe




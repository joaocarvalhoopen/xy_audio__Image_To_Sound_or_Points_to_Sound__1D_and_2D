# xy_audio  Image To Sound or Points to Sound, 1D and 2D
A simple way to ear a list of 1D and 2D points or the lines of the contour of an image.

## Description
This is a simple lib that allows you to generate an WAV audio file from 1D and 2D list of points. It has the start of an example of how to convert a image into sound. This is a work in progress, but several features already work. Currently the image must be a RGB image with a simple open or closed line with only two colors black and white. The image is converted to a list of points of the path and then to sound. The transition between points and different frequencies is done with a simple chirp that makes a "kind of" interpolation or smooth transition between the different frequencies ( positions in the XY image ). The left channel is the XX axis and the right channel is the YY axis. And the range of frequencies for the XX channel are lower than the YY channel. <br>
<br>
In the future, the idea is to have the image processed in the following way: <br>
1. Convert the image from RGB to gray scale.
2. Apply a contour filter to detect the contours in the gray scale image.
3. Find all the lines centers and a direction in it, and filter the smallest lines, like one pixel or 5 pixels line.
4. Divide the image into 6 or 9 regions and construct a graph with the lines and it's relations, inside or outside the regions, and inside other lines or regions.
5. Detect closed lines and lines with nodes or branches and multiple paths.
6. Convert the lines to a list of points and then to sound, with pauses, pen.OFF in  between the lines and the branches.
7. Generate the WAV sound file.

## How to compile and run

```
# To compile do ...

$ make

or 

$ make opti_max

# Then to run do ...

$ make run
```

## License
MIT Open Source license

## Have fun
Best regards, <br>
Joao Carvalho <br>


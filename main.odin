// Project : xy_audio - Image To Sound or Points to Sound, 1D and 2D
//
// Description: This is a simple lib that allows you to generate an WAV audio file
//              from 1D and 2D list of points.
//              It has the start of an example of how to convert a image into sound.
//              This is a work in progress, but several features already work.
//              Currently the image must be a RGB image with a simple open or closed
//              line with only two colors black and white.
//              The image is converted to a list of points of the path and then to sound.
//              The transition between points and different frequencies is done with
//              a simple chirp that makes a "kind of" interpolation or smoth transition
//              between the different frequencies ( positions in the XY image ).
//              The left channel is the XX axis and the right channel is the YY axis.
//              And the range of frequencies for the XX channel are lower than the
//              YY channel.
//
//              In the future, the ideia is to have the image processed in the following
//              way:
//
//              1. Convert the image from RGB to gray scale.
//              2. Apply a contour filter to detect the contours in the gray scale image.
//              3. Find all the lines centers and a diretion in it, and filter the smallest
//                 lines, like one pixel or 5 pixels line.
//              4. Divide the image into 6 or 9 regions and construct a graph with the
//                 lines and it's relations, inside or outside the regions, and inside
//                 other lines or regions.
//              5. Detect closed lines and lines with nodes or branches and multiple paths.
//              6. Convert the lines to a list of points and then to sound, with pauses,
//                 pen.OFF in  between the lines and the branches.
//              7. Generate the sound file.
//
// Author: Joao Carvalho
//
// Date: 2024.06.26
//
// License: MIT Open Source License
//
// Have fun.
//


package main

import "core:fmt"
import "core:strings"
import "core:math"
import "core:os"

import xya "./xy_audio"
import img "./img_load_save_to_file"

PIXEL_WHITE :: 255

NOT_VISITED : f32 :   0.0
VISITED     : f32 : 255.0
PATH_FOUND  : f32 : 128.0
START_POINT : f32 :  64.0

// Debug
counter : int = 0 


follow_the_line :: proc ( img_source     : ^img.Image_Gray,
                          visited        : ^img.Image_Gray,
                          points_2d      : ^[ dynamic ]xya.Point_2D,
                          x              : int,
                          y              : int,
                          is_first_point : bool ) {

    // counter += 1
    
    // fmt.printfln("Counter: %v, [ x, y ] = [ %v, %v ]", counter, x, y)

    // Stop condition.
    
    // if out of bounds of the image return.
    if x < 0 || x >= img_source^.cols || y < 0 || y >= img_source^.rows {
        return
    }

    // If already visited return.
    val := img.gray_get_pixel( visited, x, y ) 
    if val == VISITED || val == PATH_FOUND || val == START_POINT {
        return
    }

    // If the pixel in the image is not white set has visited and return.
    pixel := img.gray_get_pixel( img_source, x, y )
    if pixel == 0 {
        img.gray_set_pixel( visited, x, y, VISITED )
        return
    }
    
    // Set the pixel has visited.
    if is_first_point {
        img.gray_set_pixel( visited, x, y, START_POINT )
    } else {
        img.gray_set_pixel( visited, x, y, PATH_FOUND )
    }


    // The pixel is WHITE so we are adding to the list.
    // If distance < 3 pixels to the last added element we add a point to the list.
    if len( points_2d ) != 0 {
        // points_2d list is not empty
    
        last_index := len( points_2d ) - 1
        last_point := points_2d[ last_index ]
        y_inverted := img_source^.rows - y
        distance := math.sqrt( math.pow( f32( last_point.x - x ), 2 ) + math.pow( f32( last_point.y - y_inverted ), 2 ) )
        
        if distance <  3.0 {
            counter += 1
            // When you had a point you invert it in yy.
            y_inverted := img_source^.rows - y
            append_elems( points_2d, xya.Point_2D{ x = x, y = y_inverted, pen = .ON } )
        } else {
            fmt.printfln( "ignored point [ x, y ] = [ %v, %v ], distance : %v", x, y, distance )
        }
    
    } else {
        // points_2d list is empty
        counter += 1
        y_inverted := img_source^.rows - y
        append_elems( points_2d, xya.Point_2D{ x = x, y = y_inverted, pen = .ON } )
    }


    is_first_point := is_first_point
    if is_first_point {

        // Search the neighboors.

        // right
        follow_the_line( img_source, visited, points_2d, x + 1, y, false )

        // right-down
        follow_the_line( img_source, visited, points_2d, x + 1, y + 1, false )

        // down
        follow_the_line( img_source, visited, points_2d, x, y + 1, false )

        is_first_point = false
        return
    }

    // Search the neighboors.

    // right
    follow_the_line( img_source, visited, points_2d, x + 1, y, false )

    // right-down
    follow_the_line( img_source, visited, points_2d, x + 1, y + 1, false )

    // down
    follow_the_line( img_source, visited, points_2d, x, y + 1, false )

    // left-down
    follow_the_line( img_source, visited, points_2d, x - 1, y + 1, false )

    // left
    follow_the_line( img_source, visited, points_2d, x - 1, y, false )
    
    // left-up
    follow_the_line( img_source, visited, points_2d, x - 1, y - 1, false )

    // up
    follow_the_line( img_source, visited, points_2d, x, y - 1, false )

    // up-right
    follow_the_line( img_source, visited, points_2d, x + 1, y - 1, false )
}

get_image_line_points :: proc ( img_path : string, img_filename : string ) ->
                              ( points_2d : [ dynamic ] xya.Point_2D, ok : bool ) {


    image_source_path_name := fmt.aprintf( "%s%s", img_path, img_filename )

    image_source_ptr : ^img.Image_Gray
    image_source_ptr, ok = img.gray_load_image( image_source_path_name )
    if !ok {
        fmt.printfln( "Error: While loading the image source to translate to sound." )
        os.exit( 1 )
    }
    
    fmt.printfln( "Image source loaded and converted to gray scale:\n %v\n %v",
                  image_source_path_name, ok )

    num_channels := 1
    img_visited_ptr : ^img.Image_Gray
    img_visited_ptr = img.gray_create( image_source_ptr.cols,
                                       image_source_ptr.rows,
                                       num_channels )
    if img_visited_ptr == nil {
        fmt.printfln( "Error: While creating the image visited." )
        os.exit( 1 )
    }

    fmt.printfln( "Image visited created." )

    // Initialize the image visited to zero value, NOT_VISITED.
    value := NOT_VISITED
    for y in 0 ..< img_visited_ptr.rows {
        for x in 0 ..< img_visited_ptr.cols {
            img.gray_set_pixel( img_visited_ptr, x, y, value )
        }
    }

    // Process the image.
    start_x : int
    start_y : int

    // Find the starting point.
    loop: for y in 0 ..< image_source_ptr.rows {
                for x in 0 ..< image_source_ptr.cols {
                    pixel := img.gray_get_pixel( image_source_ptr, x, y )

                    if pixel != 0.0 {
                        fmt.printfln("Found starting point at [%v,%v] = %v", x, y, pixel )
                        start_x = x
                        start_y = y
                        break loop // leaves both loops
                    }

                    // Set visited point, we are not setting the first point we have found has visited.
                    img.gray_set_pixel( img_visited_ptr, x, y, VISITED )

                    // fmt.printfln("Pixel[%v,%v] = %v", x, y, pixel )
                }
    }

    // if true do os.exit( 1 )


    points_2d = make( [ dynamic ]xya.Point_2D, len=0, cap=10_000 )
    if points_2d == nil {
        fmt.printfln("Error: points_2d == nil.")
        os.exit( 1 )
    }

    // Follow the line.

    // append_elems( & points_2d, xya.Point_2D{ x = start_x, y = start_y, pen = .ON } )

    x := start_x
    y := start_y

    // Follow the line till the end.
    is_first_point := true
    follow_the_line( image_source_ptr,
                     img_visited_ptr,
                     & points_2d,
                     x,
                     y,
                     is_first_point )
    
    // Save the image visited to file.
    visited_img_out_path := "./img_out/"
    visited_img_out_filename := "visited_image.png"
    visited_image_path_name := fmt.aprintf( "%s%s",
                                   visited_img_out_path,
                                   visited_img_out_filename )

    ok = img.gray_save_image( img_visited_ptr,
                              visited_image_path_name,
                              .PNG )
    if !ok {
        fmt.printfln( "Error: While saving the visited image." )
        os.exit( 1 )
    }

    fmt.printfln( "Pixeis in the line, counter : %v", counter )

    return points_2d, true
}

example_simple_image_to_sound :: proc ( ) {

    fmt.printfln( "===>>> Example: Simple image to sound ...\n" )

    img_path := "./img_in/"
    img_filename := "flag_form.png"

    path := "./wav_out/"
    output_filename := "output_example_simple_image_to_sound.wav"

    points_2d, ok := get_image_line_points( img_path, img_filename )
    if ! ok {
        fmt.printfln( "Error: get_image_line_points() failed." )
        os.exit( 1 )
    }
    defer delete( points_2d )

    // min_len_xx :=   0   // pixels
    // max_len_xx := 600   // pixels

    // min_len_yy :=   0   // pixels
    // max_len_yy := 400   // pixels


    min_len_xx := max( int )   // pixels
    max_len_xx := min( int )   // pixels
 
    min_len_yy := max( int )   // pixels
    max_len_yy := min( int )   // pixels

    // Find min and max in XX and YY.
    for elem, index in points_2d {
        min_len_xx = min( min_len_xx, elem.x )
        max_len_xx = max( max_len_xx, elem.x )

        min_len_yy = min( min_len_yy, elem.y )
        max_len_yy = max( max_len_yy, elem.y )

        // fmt.printfln( "index : %v  point_2D  [ x, y ] = [ %v, %v ]", index, elem.x, elem.y )
    }

    time_between_points := 0.02 // 0.03 // 0.1  // 0.1 seconds

    pen_off_time        := 1.0  // seconds

    volume              := 0.3  // 0.0 to 1.0

    xy_audio_ptr, ok_1 := xya.xy_audio_make_2D( points_2d[ : ],
                                                min_len_xx,
                                                max_len_xx,
                                                min_len_yy,
                                                max_len_yy,
                                                time_between_points,
                                                pen_off_time,
                                                volume )

    if ! ok_1 {
        fmt.printfln("Error: xy_audio_make failed.")
        os.exit( 1 )
    }


/*    
    // Convert 2D to 1D first coordiinate XX.
    points_1d := make( [ dynamic ]xya.Point_1D, len=0, cap=10_000 )

    // // Copy the XX axies X points.
    // for elem in points_2d {
    //     append_elems( & points_1d, xya.Point_1D{ x = elem.x, pen = .ON } )
    // }


    // Copy the YY axies Y points.
    for elem in points_2d {
        append_elems( & points_1d, xya.Point_1D{ x = elem.y, pen = .ON } )
    }
    min_len_xx = min_len_yy
    max_len_xx = max_len_yy

    xy_audio_ptr, ok_1 := xya.xy_audio_make_1D( points_1d[ : ],
                                                min_len_xx,
                                                max_len_xx,
                                                time_between_points,
                                                pen_off_time,
                                                volume )

    if ! ok_1 {
        fmt.printfln("Error: xy_audio_make failed.")
        os.exit( 1 )
    }

*/


    error_msg, ok_2 := xya.xy_audio_gen_wav( xy_audio_ptr,
                                             path,
                                             output_filename )

    if ! ok_2 {
        fmt.printfln("Error: xy_audio_gen_wav() failed.")
        fmt.printfln( error_msg )
        os.exit( 1 )
    }

    xya.xy_audio_destroy( & xy_audio_ptr )

    fmt.printfln("Output file sucessefully written to disk:\n   %v%v", path, output_filename)
}



main :: proc ( ) {

    fmt.printfln("Begin of xy_audio ...\n")

    // NOTE: Uncomment the test you want to run.

    // xya.test_1d( )

    // xya.test_2d( )

    // xya.example_plot_of_a_cubic_polinomeal( )

    example_simple_image_to_sound( )   

    fmt.printfln("\n...end of xy_audio lib.")
}



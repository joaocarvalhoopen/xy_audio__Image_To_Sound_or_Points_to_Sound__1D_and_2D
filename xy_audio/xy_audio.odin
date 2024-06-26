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
//              7. Generate the WAV sound file.
//
// Author: Joao Carvalho
//
// Date: 2024.06.26
//
// License: MIT Open Source License
//
// Have fun.
//


package xy_audio

import "core:fmt"
import "core:strings"
import "core:math"
import "core:os"

import wav "./../wave_tools"

XX_FREQ_MIN :: 100    // Hz
XX_FREQ_MAX :: 550    // Hz

YY_FREQ_MIN ::  600   // 1500  // 600    // Hz
YY_FREQ_MAX :: 1200   // 3000  // 1200   // Hz

BITS_PER_SAMPLE :: 16     // bits
SAMPLE_RATE     :: 44100  // Hz

Points_type :: enum {
    T_1D,
    T_2D,
}

Pen_state :: enum {
    ON,
    OFF,
}

Point_2D :: struct {
    x   : int,           // pixels
    y   : int,           // pixels
    pen : Pen_state,
}

Point_1D :: struct {
    x   : int,           // pixels
    pen : Pen_state,
}

XY_Audio :: struct {
    points_type         : Points_type,
    path                : string,
    filename            : string,
    points              : [ dynamic ]Point_2D,
    min_len_xx          : int,
    max_len_xx          : int,
    min_len_yy          : int,
    max_len_yy          : int,
    time_between_points : f32,  // seconds
    pen_off_time        : f32,  // seconds
    volume              : f32,  // 0.0 to 1.0
}

// Parameter:
//     Points can be a zero list of points.
@(private="file")
xy_audio_make :: proc ( points_type         : Points_type,  
                        points              : [ ]Point_2D,
                        min_len_xx          : int,
                        max_len_xx          : int,
                        min_len_yy          : int,
                        max_len_yy          : int,
                        time_between_points : f64,
                        pen_off_time        : f64,
                        volume              : f64 ) ->
                      ( xy_audio : ^XY_Audio, ok : bool ) {

    // Allocate the XY_Audio struct.
    xy_audio = new( XY_Audio )
    if xy_audio == nil {
        fmt.printfln( "ERROR: While allocating the XY_Audio struct." ) 
        return nil, false
    }

    // Allocate the points dynamic array.
    capacity := len( points )
    if len( points ) == 0 {
        capacity = 1000
    }
    xy_audio^.points = make( [ dynamic ] Point_2D, len=0, cap=capacity )
    if xy_audio^.points == nil {
        fmt.printfln( "ERROR: While allocating the points dynamic array inside the XY_Audio struct." )
        return nil, false
    }

    // Append the points to the dynamic array.
    for p in points {
        append_elem( & xy_audio^.points, p )
    }

    // Set the type.
    xy_audio^.points_type = points_type

    // Set the min_len_xx and max_len_yy.
    xy_audio^.min_len_xx = min_len_xx
    xy_audio^.max_len_xx = max_len_xx
    xy_audio^.min_len_yy = min_len_yy
    xy_audio^.max_len_yy = max_len_yy

    // Set the time_between_points.
    xy_audio^.time_between_points = f32( time_between_points )

    // Set the pen_off_time.
    xy_audio^.pen_off_time = f32( pen_off_time )

    // Set the volume.
    xy_audio^.volume = f32( volume )
    
    return xy_audio, true
}

xy_audio_make_1D :: proc ( points_1d           : [ ]Point_1D,
                           min_len_xx          : int,
                           max_len_xx          : int,
                           time_between_points : f64,
                           pen_off_time        : f64,
                           volume              : f64 ) ->
                         ( xy_audio : ^XY_Audio, ok : bool ) {


    points_xy_internal := make( [ dynamic ]Point_2D, len=0, cap=len( points_1d ) )
    if points_xy_internal == nil {
        fmt.printfln( "ERROR: While allocating the points_xy_internal dynamic array." )
        return nil, false
    }
    defer delete( points_xy_internal )

    for p in points_1d {
        append_elem( & points_xy_internal, Point_2D{ x=p.x, y=0, pen=p.pen } )
    }

    min_len_yy := min_len_xx
    max_len_yy := max_len_xx

    xy_audio, ok = xy_audio_make( Points_type.T_1D,
                                  points_xy_internal[ : ],
                                  min_len_xx,
                                  max_len_xx,
                                  min_len_yy,
                                  max_len_yy,
                                  time_between_points,
                                  pen_off_time,
                                  volume )
    
    return xy_audio, ok
}

xy_audio_make_2D :: proc ( points_2d           : [ ]Point_2D,
                           min_len_xx          : int,
                           max_len_xx          : int,
                           min_len_yy          : int,
                           max_len_yy          : int,
                           time_between_points : f64,
                           pen_off_time        : f64,
                           volume              : f64 ) ->
                         ( xy_audio : ^XY_Audio, ok : bool ) {

    xy_audio, ok = xy_audio_make( Points_type.T_2D,
                                  points_2d,
                                  min_len_xx,
                                  max_len_xx,
                                  min_len_yy,
                                  max_len_yy,
                                  time_between_points,
                                  pen_off_time,
                                  volume )

    return xy_audio, ok
}

add_points_1d :: proc ( xy_audio : ^XY_Audio, points : [ ]Point_1D ) {
    
    assert( xy_audio != nil,
            "ERROR: The xy_audio is nil." )
    
    for p in points {
        append_elem( & xy_audio^.points, Point_2D{ x=p.x, y=0, pen=p.pen } )
    }
}


add_points_2d :: proc ( xy_audio : ^XY_Audio, points : [ ]Point_2D ) {
    
    assert( xy_audio != nil,
        "ERROR: The xy_audio is nil." )

    // Append the points to the dynamic array.
    append_elems( & xy_audio^.points, ..points )
}


// def generate_chirp(sample_rate, chirp_duration, start_freq, end_freq):
//     f_0 = start_freq
//     f_1 = end_freq
//     start = 0.0
//     stop = chirp_duration
//     step = 1.0 / sample_rate
//     t = np.arange(start, stop, step, dtype='float')
//     phase = 0.0
//     chirp_period = chirp_duration # 1 / 100.0 #1.0
//     k = (f_1 - f_0) / chirp_period
//     s = np.sin(phase + 2*np.pi * ( f_0*t + (k/2)*np.square(t)) )
//     len_s = s.size
//     return (t, s, len_s)


// To cut the rufness of the sound transitions.
@(private="file")
fade_in_out_samples :: proc ( buf_data : [ ]f32, initial_index : int ) {
    num_samples :: 500 // 40 // 15
    len_buf_data := len( buf_data )
    if len_buf_data <= num_samples * 2 {
        return
    }
    // Fade in
    for i in 0 ..< num_samples {
        buf_data[ initial_index + i ] *= f32( i ) / num_samples
    }
    // Fade out
    for i in 0 ..< num_samples {
        buf_data[ len_buf_data - 1 - i ] *= f32( i ) / num_samples
    }
}

// To cut the rufness of the sound transitions.
@(private="file")
fade_in_out_samples_until_zero :: proc ( buf_data : [ ]f32, initial_index : int ) {
    num_samples :: 150 // 40 // 15
    len_buf_data := len( buf_data )
    if len_buf_data <= num_samples * 2 {
        return
    }
    // Fade in
    for i in 0 ..< num_samples {
        if abs( buf_data[ initial_index + i + 1 ] ) <= 0.001  {
            break
        }
        buf_data[ initial_index + i ] = 0.0
    }

    // Fade out
    for i in 0 ..< num_samples {

        if abs( buf_data[ len_buf_data - 1 - i ] ) < 0.001 {
            break
        } 
        buf_data[ len_buf_data - 1 - i ] = 0.0
    }
}


@(private="file")
calc_chirp :: #force_inline proc ( f_start : f32,
                                   t       : f32,
                                   k       : f32 ) -> f32 {
    return math.cos(  2.0 * math.PI * ( f_start * t + 0.5 * k * math.pow( t, 2 ) ) )
} 

@(private="file")
calc_and_adds__xy_chirp_values :: proc ( xy_audio      : ^XY_Audio,
                                         left_channel  : ^[ dynamic ]f32,
                                         right_channel : ^[ dynamic ]f32,
                                         point_a       : Point_2D,
                                         point_b       : Point_2D,
                                         duration      : f32 ) {

    min_len_xx := xy_audio^.min_len_xx
    min_len_yy := xy_audio^.min_len_yy
    max_len_xx := xy_audio^.max_len_xx
    max_len_yy := xy_audio^.max_len_yy
    volume     := xy_audio^.volume

    initial_len := len( left_channel^ )

    duration_in_samples := int( duration * SAMPLE_RATE )
    
    // Map f_end and f_start in XX with max_len_xx .
    f_start : f64 = XX_FREQ_MIN + ( f64( point_a.x - min_len_xx ) / f64( max_len_xx - min_len_xx ) ) * ( XX_FREQ_MAX - XX_FREQ_MIN )
    f_end   : f64 = XX_FREQ_MIN + ( f64( point_b.x - min_len_xx ) / f64( max_len_xx - min_len_xx ) ) * ( XX_FREQ_MAX - XX_FREQ_MIN ) 
    
    k : f64 = ( f_end - f_start ) / f64( duration )
    
    // fmt.printfln( "f_start: %v, f_end: %v, k: %v", f_start, f_end, k )

    // Append chirp A samples XX.
    for i in 0 ..< duration_in_samples {
        t := f32( i ) / f32( SAMPLE_RATE )
        value : f32 = calc_chirp( f32( f_start ), t, f32( k ) )
        value *= volume
        append_elem( & left_channel^, value )
    }
    
    initial_index := initial_len - 1 if initial_len > 0 else 0 
    
    // Map f_end and f_start in YY with max_len_yy .
    f_start = YY_FREQ_MIN + ( f64( point_a.y - min_len_yy ) / f64( max_len_yy - min_len_yy ) ) * ( YY_FREQ_MAX - YY_FREQ_MIN )
    f_end   = YY_FREQ_MIN + ( f64( point_b.y - min_len_yy ) / f64( max_len_yy - min_len_yy ) ) * ( YY_FREQ_MAX - YY_FREQ_MIN ) 

    k = ( f_end - f_start ) / f64( duration )


    // Append chirp B samples YY.
    for i in 0 ..< duration_in_samples {
        t := f32( i ) / f32( SAMPLE_RATE )
        value : f32 = calc_chirp( f32( f_start ), t, f32( k ) )
        value *= volume
        append_elem( & right_channel^, value )
    }

    // // Append chirp B samples YY.
    // for i in initial_index ..< len( wav_buf^ ) {
    //     t := f32( i ) / f32( SAMPLE_RATE ) 
    //     value := calc_chirp( f32( f_start ), t, f32( k ) )
    //     wav_buf^[ i ] += value 
    //     // Makes the average of the two signals, Mixing of the 2 signals.
    //     wav_buf^[ i ] /= 2.0
    // }

    fade_in_out_samples( left_channel^[ : ],
                         initial_index )
    
    fade_in_out_samples( right_channel^[ : ],
                         initial_index )
}

@(private="file")
calc_and_adds__silence :: proc ( xy_audio      : ^XY_Audio,
                                 left_channel  : ^[ dynamic ]f32,
                                 right_channel : ^[ dynamic ]f32,
                                 duration      : f32 ) {

    duration_in_samples := int( duration * SAMPLE_RATE )

    value : f32 = 0
    // Append a silence to samples XX and YY.
    for i in 0 ..< duration_in_samples {
        append_elem( & left_channel^,  value )
        append_elem( & right_channel^, value )
    }
}

@(private="file")
save_to_wav_file :: proc ( xy_audio        : ^XY_Audio,
                           left_channel    : [ ]f32,
                           right_channel   : [ ]f32,
                           path            : string,
                           output_filename : string ) ->
                         ( error_msg : string, ok : bool ) {
    
    wav_info : wav.WavInfo
    wav_error : wav.WAVError
    
    // Write the wav file.
    if xy_audio^.points_type == Points_type.T_1D {
        wav_info, wav_error = wav.wav_info_create( output_filename,
                                                    path,
                                                    1,
                                                    u32( SAMPLE_RATE ),
                                                    BITS_PER_SAMPLE )
    } else if xy_audio^.points_type == Points_type.T_2D {
        wav_info, wav_error = wav.wav_info_create( output_filename,
                                                    path,
                                                    2,
                                                    u32( SAMPLE_RATE ),
                                                    BITS_PER_SAMPLE )
    }
    
    // wav_info, wav_error := wav.wav_info_create( output_filename,
    //                                             path,
    //                                             2,
    //                                             u32( SAMPLE_RATE ),
    //                                             BITS_PER_SAMPLE )
    
    if wav_error.(wav.Error).type != wav.ErrorType.No_Error {
        error_str := wav_error.(wav.Error).description
        erro_msg := fmt.aprintf( "Error creating the wav file: %s\n", error_str )
        return error_msg, false
    }

    if xy_audio^.points_type == Points_type.T_1D {
        wav_error = wav.set_buffer_d32_normalized( & wav_info,
                                                   left_channel,
                                                   nil )
    } else if xy_audio^.points_type == Points_type.T_2D {
        wav_error = wav.set_buffer_d32_normalized( & wav_info,
                                                   left_channel,
                                                   right_channel )
    }

    // wav_error = wav.set_buffer_d32_normalized( & wav_info,
    //                                            left_channel,
    //                                            right_channel )

    if wav_error.(wav.Error).type != wav.ErrorType.No_Error {
        error_str := wav_error.(wav.Error).description
        error_msg := fmt.aprintf( "Error setting the buffer: %s\n", error_str )
        return error_msg, false
    }

    wav_error = wav.wav_write_file( & wav_info )
    if wav_error.(wav.Error).type != wav.ErrorType.No_Error {
        error_str := wav_error.(wav.Error).description
        error_msg := fmt.aprintf( "Error writing the wav file: %s\n", error_str )
        return error_msg, false
    }

    wav.wav_info_destroy( & wav_info )

    return "The WAV file was correctly written to disk.", true
}

xy_audio_gen_wav :: proc ( xy_audio        : ^XY_Audio,
                           path            : string,
                           output_filename : string ) ->
                         ( error_msg : string, ok : bool ) {
    
    assert( xy_audio != nil,
            "ERROR: The xy_audio is nil." )
    assert( len( xy_audio^.points ) > 0,
            "ERROR: The number of points in xy_audio is zero." )

    // Allocating the left and the right channels.
    left_channel := make( [ dynamic ]f32, len=0, cap=1_000_000 )
    if left_channel == nil {
        return "ERROR: While allocating the left_channnel dynamic array.", false
    }
    defer delete( left_channel )

    right_channel := make( [ dynamic ]f32, len=0, cap=1_000_000 )
    if right_channel == nil {
        return "ERROR: While allocating the right_channnel dynamic array.", false
    }
    defer delete( right_channel )


    last_point : Point_2D = xy_audio^.points[ 0 ]

    flag_last_pen_off := false

    // for i in 1 ..< len( xy_audio^.points ) {
    for i : int = 1; i < len( xy_audio^.points ) ; i += 1 {
        curr_point := xy_audio^.points[ i ]
 
        if curr_point.pen == Pen_state.OFF {
            last_point = curr_point
            flag_last_pen_off = true

            calc_and_adds__silence( xy_audio,
                                    & left_channel,
                                    & right_channel,
                                    xy_audio^.pen_off_time )

            continue
        } else if curr_point.pen == Pen_state.ON && flag_last_pen_off {
            flag_last_pen_off = false
            last_point = curr_point

            // It will going to play a single tone, but the starting and ending
            // freqency will not be the same, so it doesn't anule it's in a
            // subtration of the interval of frequencies.
            calc_and_adds__xy_chirp_values( xy_audio,
                                            & left_channel,
                                            & right_channel,    
                                            curr_point,
                                            curr_point,
                                            xy_audio^.time_between_points )


            continue
        }
        

        // TODO: Make a diference if points are distant then one pixel left right up or down.

        calc_and_adds__xy_chirp_values( xy_audio,
                                        & left_channel,
                                        & right_channel,    
                                        last_point,
                                        curr_point,
                                        xy_audio^.time_between_points )
        
        last_point = curr_point
    }


    // If difference > XPTO 1 distance in X and 1 distance in y then interpolate.

    error_msg, ok = save_to_wav_file( xy_audio,
                                      left_channel[ : ],
                                      right_channel[ : ],
                                      path,
                                      output_filename )

    return error_msg, ok
}

// Recilagem de memoria, memoria composting, circular ecoonomy :-)
xy_audio_destroy :: proc ( xy_audio : ^^XY_Audio ) {

    if xy_audio^ == nil {
        return
    }

    delete( xy_audio^^.points )

    free( xy_audio^ )

    xy_audio^ = nil
}

//
// Test 1D
//

test_1d :: proc ( ) {

    fmt.printfln( "===>>> Test 1D \n" )

    path            := "./wav_out/"
    output_filename := "output_test_1d.wav"

    points_1d := [ ] Point_1D {
       //  X,  pen_up_or_down
        { 100, .ON  }, // ON means pen down, OFF para pen up.
        {  50, .ON  },
        {  50, .OFF },
        {   1, .ON  },
        {  50, .ON  },
        { 120, .ON  },
    }

    min_len_xx :=  1
    max_len_xx := 120 

    time_between_points := 1.0  // 0.1 seconds

    pen_off_time        := 1.0  // seconds

    volume              := 0.3  // 0.0 to 1.0

    xy_audio_ptr, ok_1 := xy_audio_make_1D( points_1d,
                                            min_len_xx,
                                            max_len_xx,
                                            time_between_points,
                                            pen_off_time,
                                            volume )
    if ! ok_1 {
        fmt.printfln("Error: xy_audio_make failed.")
        os.exit( 1 )
    }

    // add_points_1d( points_1d )
    
    error_msg, ok_2 := xy_audio_gen_wav( xy_audio_ptr,
                                         path,
                                         output_filename )
    if ! ok_2 {
        fmt.printfln( "Error: xy_audio_gen_wav() failed." )
        fmt.printfln( error_msg )
        os.exit( 1 )
    }

    xy_audio_destroy( & xy_audio_ptr )

    fmt.printfln( "Output file sucessefully written to disk:\n   %v%v", path, output_filename )

    fmt.printfln( "\n...end of test_1d().\n" )
}

//
// Test 2D
//

test_2d :: proc ( ) {

    fmt.printfln( "===>>> Test 2D \n" )

    path            := "./wav_out/"
    output_filename := "output_test_2d.wav"

    points_2d := [ ] Point_2D {
       //  X,   Y, pen_up_or_down
        {  0, 100, .ON }, // ON means pen down, OFF para pen up.
        { 20,  50, .ON },
        { 40,   1, .ON },
        { 60,  50, .ON },
        { 80, 120, .ON },
    }

    min_len_xx :=   0
    max_len_xx :=  80

    min_len_yy :=   1
    max_len_yy := 120 

    time_between_points := 1.0  // 0.1 seconds

    pen_off_time        := 1.0  // seconds

    volume              := 0.3  // 0.0 to 1.0

    xy_audio_ptr, ok_1 := xy_audio_make_2D( points_2d,
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

    // add_points_2d( points_2d )
    
    error_msg, ok_2 := xy_audio_gen_wav( xy_audio_ptr,
                                         path,
                                         output_filename )
    if ! ok_2 {
        fmt.printfln("Error: xy_audio_gen_wav() failed.")
        fmt.printfln( error_msg )
        os.exit( 1 )
    }

    xy_audio_destroy( & xy_audio_ptr )

    fmt.printfln("Output file sucessefully written to disk:\n   %v%v", path, output_filename)

    fmt.printfln("\n...end of test_2d().\n")
}

example_plot_of_a_cubic_polinomeal :: proc ( ) {
    // f( x ) = ( x^3 + 3 * x^2 - 6 * x - 8 ) / 4
    //
    // Region of interest:
    // [ -5.2, 3.5 ]

    points_1D := make( [ dynamic ] Point_1D, len=0, cap=100 )

    max_len_xx : int = min( int )
    min_len_xx : int = max( int ) 
    for x := -5.2; x <= 3.5; x += 0.1 {
        y := ( math.pow( x, 3 ) + 3 * math.pow( x, 2 ) - 6 * x - 8 ) / 4
        y_int := int( y * 10 )
        append( & points_1D, Point_1D{ x=y_int, pen=Pen_state.ON } )
        fmt.printfln( "x: %v, y: %v", x, y )
        min_len_xx = min( min_len_xx, y_int )
        max_len_xx = max( max_len_xx, y_int )
    }

    fmt.printfln( "min_len_xx: %v, max_len_xx: %v", min_len_xx, max_len_xx )

    max_len_xx = max_len_xx - min_len_xx   

    path            := "./wav_out/"
    output_filename := "output_example_plot_of_a_cubic_polinomeal.wav"

    time_between_points := 0.1  // 0.1 seconds

    pen_off_time        := 1.0  // seconds

    volume              := 0.3  // 0.0 to 1.0

    xy_audio_ptr, ok_1 := xy_audio_make_1D( points_1D[ : ],
                                            min_len_xx,
                                            max_len_xx,
                                            time_between_points,
                                            pen_off_time,
                                            volume )

    if ! ok_1 {
        fmt.printfln("Error: xy_audio_make failed.")
        os.exit( 1 )
    }

    error_msg, ok_2 := xy_audio_gen_wav( xy_audio_ptr,
                                         path,
                                         output_filename )

    if ! ok_2 {
        fmt.printfln("Error: xy_audio_gen_wav() failed.")
        fmt.printfln( error_msg )
        os.exit( 1 )
    }

    xy_audio_destroy( & xy_audio_ptr )

    fmt.printfln("Output file sucessefully written to disk:\n   %v%v", path, output_filename)
}




//
// The following structs are used to represent the graph of connected segments.
//

Quadrant_9 :: enum {
    Q1,
    Q2,
    Q3,
    Q4,
    Q5,
    Q6,
    Q7,
    Q8,
    Q9,
}

Segment_2D :: struct {
    id               : int,
    points_list      : [ dynamic ]Point_2D,
    start            : Point_2D,
    end              : Point_2D,
    inside_quadrants : [ dynamic ]Quadrant_9,
}

// Nodes or connections between segments
Connections_2D :: struct {
    id        : int,
    point     : Point_2D,
    segment_A : ^Segment_2D,
    segment_B : ^Segment_2D,
}

Connected_graph :: struct {
    id               : int,
    segments_list    : [ dynamic ]^Segment_2D,
    connection_list  : [ dynamic ]Connections_2D,
    inside_quadrants : [ dynamic ]Quadrant_9,
}

All_graphs :: struct {
    connected_graphs_list : [ dynamic ]^Connected_graph,
    order_of_show_list    : [ dynamic ]^Connected_graph,
}

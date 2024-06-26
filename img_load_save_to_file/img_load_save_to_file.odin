package img_load_save_to_file

import "core:fmt"
import "core:math"
import "core:strings"
import "core:os"
import "base:runtime"
import "core:math/cmplx"

// NOTE: In Linux, you need to compile this module you need to go to the
//       diretory of Odin/vendor/stb/src and run the following command:
//
//        $ cd Odin/vendor/stb/src
//        $ make
//
//        Then in this project diretory you can compile this project
//        normally with make or make opti_max .
// 
import img "vendor:stb/image"


Img_Type :: enum {
    None,
    PNG,
    JPG,
    BMP,
    TGA,
    GIF,
    PSD,
    HDR,
    PIC,
    PNM,
}

NUM_CHANNELS : i32 = 1

Image_Gray :: struct {
    rows       : int,
    cols       : int,
    channels   : i32,
    components : i32,
    data       : []f32,
}

gray_create :: proc ( cols : int, rows : int, num_channels_p :int ) ->
                    ( image : ^Image_Gray ) {

    image = new( Image_Gray )
    if image == nil {
        fmt.println( "Error: While allocating memory for the gray image!" )
        os.exit( 1 )
    }
    image.cols       = cols
    image.rows       = rows
    image.channels   = i32( num_channels_p )   // NUM_CHANNELS
    image.components = i32( num_channels_p )   // NUM_CHANNELS
    image.data       = make( []f32, rows * cols )
    if image.data == nil {
        fmt.println( "Error: While allocating memory for the gray image!" )
        os.exit( 1 )
    }
    return image
}

gray_free :: proc ( image : ^^Image_Gray ) {
    
    delete( image^.data )
    image^.data = nil
    free( image^ )
    image^ = nil
}

gray_get_pixel :: #force_inline proc ( image : ^Image_Gray,
                                       x : int,
                                       y : int,
                                       location := #caller_location ) ->
                       ( value : f32 ) {
    
    if y < 0 || y >= image.rows || x < 0 || x >= image.cols {
        fmt.printfln( " Error: Out of bound accessed in gray_get_pixel() function!," +
                      "      col [x]: %v, row [y]: %v\n %v\n",
                      x, y, get_csting_from_location( location ) )
        os.exit( 1 )
    }
    return image.data[ y * image.cols + x ]
}

gray_set_pixel :: #force_inline proc( image : ^Image_Gray,
                                      x : int,
                                      y : int,
                                      value : f32,
                                      location := #caller_location ) {
    
    if y < 0 || y >= image.rows || x < 0 || x >= image.cols {
        fmt.printfln( " Error: Out of bound accessed in gray_set_pixel() function!," +
                      "      col [x] : %v, row [y]: %v\n %v\n",
                      x, y, get_csting_from_location( location ) )
        os.exit( 1 )
    }
    image.data[ y * image.cols + x ] = value
}

gray_image_copy :: proc ( image_source : ^Image_Gray, image_target : ^Image_Gray ) {
    assert( image_source.rows == image_target.rows )
    assert( image_source.cols == image_target.cols )
    assert( image_source.channels == image_target.channels )
    assert( image_source.components == image_target.components )
    assert( image_source.data != nil )
    assert( image_target.data != nil )

    for i in 0 ..< image_source.rows {
        for j in 0 ..< image_source.cols {
            value := gray_get_pixel( image_source, j, i )
            gray_set_pixel( image_target, j, i, value )
        }
    }
}

color_get_pixel :: #force_inline proc ( image    : ^Image_Gray,
                                        x        : int,
                                        y        : int,
                                        location := #caller_location ) ->
                                      ( r, g, b : f32 ) {

    if y < 0 || y >= image.rows || x < 0 || x >= image.cols {
        fmt.printfln( " Error: Out of bound accessed in gray_get_pixel() function!," +
                      "      col [x]: %v, row [y]: %v\n %v\n",
                      x, y, get_csting_from_location( location ) )
        os.exit( 1 )
    }

    index := 3 * (  y * image.cols + x )
    r = image.data[ index ]
    g = image.data[ index + 1 ]
    b = image.data[ index + 2 ]
    return r, g, b
}

color_set_pixel :: #force_inline proc( image     : ^Image_Gray,
                                        x        : int,
                                        y        : int,
                                        r, g, b  : f32,
                                        location := #caller_location ) {

    if y < 0 || y >= image.rows || x < 0 || x >= image.cols {
        fmt.printfln( " Error: Out of bound accessed in gray_set_pixel() function!," +
                      "      col [x] : %v, row [y]: %v\n %v\n",
                      x, y, get_csting_from_location( location ) )
        os.exit( 1 )
    }
    
    index := 3 * (  y * image.cols + x )
    image.data[ index ]     = r
    image.data[ index + 1 ] = g
    image.data[ index + 2 ] = b
}

gray_load_image :: proc ( file_name : string ) ->
                        ( res_image : ^Image_Gray, ok : bool ) {
    
    file_doesnt_existes := !os.is_file( file_name )
    if file_doesnt_existes {
        fmt.printfln( "Error: File doesn't exist: %s", file_name )
        ok := false
        res_image = nil
        return res_image, ok
    }

    size_x     : i32 = 0
    size_y     : i32 = 0
    components : i32 = 0
    
    // Load the image from the file.
    data : [ ^ ]u8 = img.load( strings.clone_to_cstring( file_name ), 
                               & size_x,
                               & size_y,
                               & components,
                               NUM_CHANNELS * 3 )
      
    // Free the image data loaded from file in [ ^ ]u8 .
    defer img.image_free( data )

    fmt.printfln( "Image loaded: %s,\n" +
                  "   size_x: %d, size_y: %d, components: %d",
                  file_name, size_x, size_y, components )


    // Check if the image was loaded.
    if data == nil {
        fmt.printfln( "Error loading image: %s", file_name )
        ok := false
        res_image = nil
        return res_image, ok
    }

    // Create the image object.
    gray_image_channels : int = 1
    res_image = gray_create( int( size_x ), int( size_y ), gray_image_channels )
  
    // Copy the u8 to f32.
    for i in 0 ..< int( size_y ) {
        for j in 0 ..< int( size_x ) {
            index := 3 * ( i * int( size_x ) + j )
            r := f32( data[ index ] )
            g := f32( data[ index + 1 ] )
            b := f32( data[ index + 2 ] )
            gray_value : f32 = ( r + b + g ) / 3
            // value := f32( data[ 3 *( i * int( size_y ) + j ) ] )
            gray_set_pixel( res_image, j, i, gray_value )
        }
    }

    return res_image, true
}

gray_save_image :: proc ( image      : ^Image_Gray,
                          file_name  : string,
                          image_type : Img_Type ) ->
                        ( ok : bool) {

    // Allocate memory for a color image data RGB.
    data : [ ^ ]u8 = make( [ ^ ]u8, image.rows * image.cols * int( NUM_CHANNELS * 3 ) )
    if data == nil {
        fmt.printfln( "Error: In gray_save_image, while allocating memory for the image data!" )
        os.exit( 1 )
    }
    defer free( data )

    // Calculate the min and the max values of the image.
    min_val : f32 = max( f32 )
    max_val : f32 = min( f32 )
    for i in 0 ..< image.rows {
        for j in 0 ..< image.cols {
            value := gray_get_pixel( image, j, i )
            min_val = math.min( min_val, value )
            max_val = math.max( max_val, value )
        }
    }

    // Copy the [ ]f32 1D buffer to [ ^ ]u8 RGB buffer.
    for i in 0 ..< image.rows {
        for j in 0 ..< image.cols {
            value := gray_get_pixel( image, j, i )

            // Scale the value to [0, 255].
            // value = ( value - min_val ) / ( max_val - min_val ) * 255.0

            // Transform the image from Gray to RGB.
            // Access the data in the pointed to 2d image by a 1D psudo vector.
            index := 3 * ( i * image.cols + j )  
            data[ index ]     = u8( value )
            data[ index + 1 ] = u8( value )
            data[ index + 2 ] = u8( value )

            // data[ i * image.cols + j ] = u8( math.round( value ) )
        }
    }

    RGB_componentes : i32 = 3
    // Stride is in bytes.
    stride : i32 = i32( image.cols ) * NUM_CHANNELS * 3 

    ret : i32

    switch image_type {
        case Img_Type.PNG:
            ret = img.write_png( 
                        strings.clone_to_cstring( file_name ),
                        i32( image.cols ),
                        i32( image.rows ),
                        RGB_componentes,                        // 4 components: RGBA
                        rawptr( & ( data[ 0 ] ) ),
                        stride )  // in bytes

        case Img_Type.JPG:
            ret = img.write_jpg( 
                        strings.clone_to_cstring( file_name ),
                        i32( image.cols ),
                        i32( image.rows ),
                        RGB_componentes,                        // 4 components: RGBA
                        rawptr( & ( data[ 0 ] ) ),
                        0 )   // No compression

        case Img_Type.BMP:
            ret = img.write_bmp( 
                        strings.clone_to_cstring( file_name ),
                        i32( image.cols ),
                        i32( image.rows ),
                        RGB_componentes,                        // 4 components: RGBA
                        rawptr( & ( data[ 0 ] ) ),
                        )

        case Img_Type.TGA:
            ret = img.write_tga( 
                        strings.clone_to_cstring( file_name ),
                        i32( image.cols ),
                        i32( image.rows ),
                        RGB_componentes,                   // 4 components: RGBA
                        rawptr( & ( data[ 0 ] ) ),
                        )

        case Img_Type.GIF:
            fmt.printfln( "Error: Writing GIF format, Unsupported image type: %d",
                          image_type )
            os.exit( 1 )

        case Img_Type.PSD:
            fmt.printfln( "Error: Writing PSD format, Unsupported image type: %d",
                          image_type )
            os.exit( 1 )

        case Img_Type.HDR:
            img.write_tga( 
                strings.clone_to_cstring( file_name ),
                i32( image.cols ),
                i32( image.rows ),
                RGB_componentes,                        // 4 components: RGBA
                rawptr( & ( data[ 0 ] ) ),  // &data[0],
                // stride
                )

        case Img_Type.PIC:
            fmt.printfln( "Error: Writing PIC format, Unsupported image type: %d",
                          image_type )
            os.exit( 1 )

        case Img_Type.PNM:
            fmt.printfln( "Error: Writing PIC format, Unsupported image type: %d",
                          image_type )
            os.exit( 1 )

        case Img_Type.None:
            fmt.printfln( "Error: Unsupported image type: %v, %v",
                          image_type, file_name )
            os.exit( 1 )

        case:
            fmt.printfln( "Error: Unsupported image type: %v, %v",
                          image_type, file_name )
            os.exit( 1 )
    }

    if ret != 1 {
        fmt.printfln( "Error saving image: %s, ret: %v", file_name, ret )
        ok = false
        return ok
    }
    
    ok = true
    return ok
}

@( private="file" )
get_csting_from_location :: proc ( loc : runtime.Source_Code_Location ) -> cstring {
    str_loc_tmp := fmt.aprintf( "%s  [ %d : %d ], %s ",
                         loc.file_path,
                                loc.line,
                                loc.column,
                                loc.procedure )
    cstr_loc := strings.clone_to_cstring( str_loc_tmp )
    delete( str_loc_tmp )
    return cstr_loc
}

get_image_type :: proc ( path_name : string ) -> Img_Type {
    // Get the file extension.
    lower := strings.to_lower( path_name )

    // Check the extension.
    switch {
        case strings.has_suffix( lower, ".png" ):
            return Img_Type.PNG
        case strings.has_suffix( lower, ".jpg" ):
            return Img_Type.JPG
        case strings.has_suffix( lower, ".jpeg" ):
            return Img_Type.JPG
        case strings.has_suffix( lower, ".bmp" ):
            return Img_Type.BMP
        case strings.has_suffix( lower, ".tga" ):
            return Img_Type.TGA
        case strings.has_suffix( lower, ".gif" ):
            return Img_Type.GIF
        case strings.has_suffix( lower, ".psd" ):
            return Img_Type.PSD
        case strings.has_suffix( lower, ".hdr" ):
            return Img_Type.HDR
        case strings.has_suffix( lower, ".pic" ):
            return Img_Type.PIC
        case strings.has_suffix( lower, ".pnm" ):
            return Img_Type.PNM
    }

    return Img_Type.None
}

c64 :: #force_inline proc ( re : f32, img : f32 ) -> complex64 {
    return complex64( complex( re, img ) )
}

map_C64_tx_pulses_to_0_255 :: proc ( val : complex64 ) ->
                                   ( gray_value : f32 ) {
    switch  {
        case val == c64( 0.0, 0.0) :
            gray_value = 128.0
        case real( val ) < 0 && imag( val ) == 0 :
            gray_value = 0.0
        case real( val ) == 0 && imag( val ) < 0 :
            gray_value = 65
        case real( val ) > 0 && imag( val ) == 0 :
            gray_value = 193.0
        case real( val ) == 0 && imag( val ) > 0 :
            gray_value = 255.0
        case:
            fmt.println( "Error: map_C64_tx_pulses_to_0_255(), default case!\n" +
                         "   Not valid case!\n" +
                         " real: %v, img: %v\n",
                         real( val ),
                         imag( val ) )
            os.exit( 1 )
    }

    return gray_value
}

Map_Func_Type :: proc ( val : complex64 ) -> ( gray_value : f32 )

save_2d_vector_c64_to_image :: proc ( m_hd_tx_pulses : [ ]complex64,
                                      len_x          : int,
                                      len_y          : int,
                                      img_file_path  : string,
                                      map_func           : Map_Func_Type ) ->
                                    ( ok : bool ) {

    assert( m_hd_tx_pulses != nil,
            "Error: save_2d_vector_c64_to_image(), m_hd_tx_pulses == nil" )
    assert( len( m_hd_tx_pulses ) == len_x * len_y,
            "Error: save_2d_vector_c64_to_image(), len( m_hd_tx_pulses ) != len_x * len_y" )
    assert( len_x > 0, "Error: save_2d_vector_c64_to_image(), len_x <= 0" )
    assert( len_y > 0, "Error: save_2d_vector_c64_to_image(), len_y <= 0" )

    // Allocate memory for GrayImage.
    image_target_ptr := gray_create( len_x, len_y, 1 )
    if image_target_ptr == nil {
        fmt.printfln( "Error: While allocating memory for the image target!" )
        ok = false
        return ok
    }
    defer gray_free( & image_target_ptr )

    // Find min and max values in the vector slice.
    min_val := max( f32 )
    max_val := min( f32 )
    for elem in m_hd_tx_pulses {
        value := math.abs( elem )
        fmt.printfln( "real: %v img: %v value: %v",
                      real( elem ),
                      imag( elem ),
                      value )
        min_val = math.min( min_val, value )
        max_val = math.max( max_val, value )
    }

    // Copy the 2D vector to the image.
    for y in 0 ..< len_y {
        for x in 0 ..< len_x {
            
            // With mapping function.
            if map_func != nil {
                gray_value := map_func( m_hd_tx_pulses[ y * len_x + x ] )
                gray_set_pixel( image_target_ptr,
                                x,
                                y,
                                gray_value )
                continue
            }

            // Without mapping function.
            val_complex := m_hd_tx_pulses[ y * len_x + x ]
            val_abs     := math.abs( val_complex )
            // Map the value from [ min, max ] to [0, 255].
            value := ( val_abs - min_val ) / ( max_val - min_val ) * 255.0

            gray_set_pixel( image_target_ptr,
                                x,
                                y,
                                value )

        }
    }

    // Get filename extension.
    img_file_type := get_image_type( img_file_path )

    // Save the image.
    ok = gray_save_image( image_target_ptr, img_file_path, img_file_type )
    if !ok {
        fmt.printfln( "Error: While saving the image target! Possibly path isn't" +
                      " correct or image type isn't correct!\n  %v\n", img_file_path )
        return ok
    }

    ok = true
    return ok
}

//
// Test the image load and save functions.
//

test_img_load_and_save :: proc ( ) -> ( ok : bool ) {

    image_source_path_name     := "./images_source/image_test_01.png"
    image_target_lee_path_name := "./images_target/image_test_01_target.jpg"

    image_source_ptr : ^Image_Gray
    image_source_ptr, ok = gray_load_image( image_source_path_name )
    if !ok {
        fmt.printfln( "Error: While loading the image source" )
        ok = false
        return ok
        // os.exit( 1 )
    }
    
    fmt.printfln("Image source loaded:\n %v\n %v", image_source_path_name, ok )


    fmt.printfln("Start processing ...\n")
    image_target_lee_ptr := gray_create( image_source_ptr.cols,
                                         image_source_ptr.rows,
                                         int( image_source_ptr.channels ) )

    gray_image_copy( image_source_ptr,
                     image_target_lee_ptr )

    gray_save_image( image_target_lee_ptr,
                            image_target_lee_path_name,
                            // filter.Img_Type.PNG )
                            Img_Type.JPG )
    fmt.printfln("Image target saved\n")

    ok = true
    return ok
}

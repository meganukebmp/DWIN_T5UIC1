# T5UIC1
## 1 Overview
The T5UIC1 is a UART based screen based on the DWIN T5 CPU. The T5UIC1 only has a single T5 CPU core and uses a unique reduced instruction set. It is best suited for low-cost applications that do not require a touchscreen or complex UI functions.

**Display features:**
* 65k color TFT display (RGB565)
* Basic drawing commands (rectangle, lines, dots)
* Chinese and ASCII text display as well as the ability to display formatted numeric variables
* JPEG icon and image decoding and display
* EAN-13 barcode generation and QR code generation
* 384kb storage for fonts
    * 6x12 to 32x64 dot matrix ASCII characters and 12x12 to 64x64 dot matrix GB2312 character library
* 512kb storage for images and icons. (Divided into 16 banks of 32kb. Single image cannot exceed 32kb)
    * Divided into 16 banks of 32kb.
    * Can store 16 JPEG images, not exceeding 32kb each.
    * Can store up to 16 JPEG icon library files. (A single library file can occupy multiple banks)
* 32kb of SRAM, for user specified data.
    * Can be read and written to during runtime. Initialized to `0` on boot.
    * Useful for uploading new pictures during runtime.
* 16kb flash memory, for user specified data.
    * Can be read and written to during runtime. Contents persist between reboots.
    * 100,000 write cycles.
    * Useful for persistent configuration options.
* MicroSD/SDHC slot for firmware, fonts & image updates.
* An additional full-duplex serial port that can be controlled through UART.
    * Useful for daisy chaining peripherals to the display on processors with a single UART line.
* Adjustable CPU clock (240MHz and 400MHz)

---

## 2 UART instruction set
The device has a configurable baud-rate. The baud-rate is configured through the SD card config file `T5UIC1.CFG`.

The serial port is always in **8N1** mode.

### 2.1 Color format
All colors are in the 16 bit **RGB565** format.
**16 Bits:**
| 15 | 14 | 13 | 12 | 11 | 10 | 9  | 8  | 7  | 6  | 5  | 4  | 3  | 2  | 1  | 0  |
|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|
| R4 | R3 | R2 | R1 | R0 | G5 | G4 | G3 | G2 | G1 | G0 | B4 | B3 | B2 | B1 | B0 |

### 2.2 Coordinate system
Coordinate system is controlled by the rotation parameter in the SD card config file `T5UIC1.CFG`

![Coordinate system](coordinates.png)

### 2.3 Display buffers
The device has a main framebuffer (that's directly drawn on the screen) and 2 virtual screen buffers. The virtual screen buffers serve for background transparency and spritesheet functions.

Virtual screen buffer #0 is always set to the currently displayed background image and is mainly used for transparent image operations by background redraw.

Virtual screen buffer #1 must be set manually and is mainly used for selecting areas from the loaded image and drawing them on to the main framebuffer (for example a spritesheet)

### 2.4 Serial data frame
A single data frame to the display consists of a frame header, instruction, data, CRC (optional) and footer.

The data frame is as such:
| Header | Instruction        | Data                    | CRC (optional) | Footer              |
|--------|--------------------|-------------------------|----------------|---------------------|
| `0xAA`   | 1 byte instruction | Up to 248 bytes of data | 2 byte CRC-16/MODBUS | `0xCC 0x33 0xC3 0x3C` |

### 2.5 CRC
CRC can be enabled in the SD card config file `T5UIC1.CFG`. The CRC is a CRC-16/MODBUS.

If any instruction fails the CRC check the device will return the following error:

| Instruction | Data |
|-------------|------|
| `0xFF`      | `0x01`|

All device responses will also generate their own CRC.

### 2.6 Instruction set
Below are all the instructions and their corresponding parameters. Every instruction follow the format described in **Serial Data Frame**. If an instruction has an expected response it is **explicitly listed**. All instructions without an expected response described, do not have any response.

---

#### `0x00` - Handshake
Check if the device is online. If it is online it will respond to this command.

**Transmit:**
| Instruction | Data (0 bytes) |
|-------------|------|
| `0x00`      | NONE |

**Expected response:**
| Instruction | Data (2 bytes) |
|-------------|------|
| `0x00`      | `0x4F 0x4B` - "OK"|

---

#### `0x01` - Clear screen
Clears the screen with a specified color.

**Transmit:**
| Instruction | Data (2 bytes) |
|-------------|------|
| `0x01`      |[2B] **COLOR** |

**COLOR:** 2 bytes

\- An **RGB565** color

---

#### `0x02` - Draw point(s)
Draw a point, or multiple points with one instruction. When drawing points all points can be given (together) a color, dimensions and location.

**Transmit:**
| Instruction | Data (8 to 248 bytes) |
|-------------|------|
| `0x02`      |[2B] **COLOR**; [1B] **SIZE_X**; [1B] **SIZE_Y**; ([2B] **X0**; [2B] **Y0**) ..... ([2B] **Xn**; [2B] **Yn**)|

**COLOR:** 2 bytes

\- An **RGB565** color

**SIZE_X:** 1 byte

\- `0x01` to `0x0F` - The pixel size of the point in the X axis 

**SIZE_Y:** 1 byte

\- `0x01` to `0x0F` - The pixel size of the point in the Y axis 

**Xn:** 2 bytes

\- The X position of the point

**Yn:** 2 bytes

\- The Y position of the point

---

#### `0x03` - Draw line(s)
Draw a line, or multiple lines with one instruction. When drawing multiple lines, the end of the last is the start of the next. This way you can draw complex line shapes and non-filled polygons. When drawing lines all lines can be given (together) a color.


**Transmit:**
| Instruction | Data (10 to 248 bytes) |
|-------------|------|
| `0x03`      |[2B] **COLOR**; ([2B] **X0**; [2B] **Y0**); ([2B] **X1**; [2B] **Y1**); ..... ([2B] **Xn**; [2B] **Yn**)|

**COLOR:** 2 bytes

\- An **RGB565** color

**Xn:** 2 bytes

\- The X position of the line point (starting or ending)

**Yn:** 2 bytes

\- The Y position of the line point (starting or ending)

---

#### `0x05` - Draw rectangle
Draw a rectangle in one of multiple modes and colors. An XOR mode is present that can be used for menu highlighting.

**Transmit:**
| Instruction | Data (11 bytes) |
|-------------|------|
| `0x05`      |[1B] **MODE** ;[2B] **COLOR** ; [2B] **X0**; [2B] **Y0**; [2B] **X1**; [2B] **Y1**;|


**MODE:** 1 byte

\- `0x00` - Draw rectangle outline only

\- `0x01` - Draw rectangle fill only

\- `0x02` - XOR content under the rectangle area. Useful for menu highlighting.

**COLOR:** 2 bytes

\- An **RGB565** color

**X0:** 2 bytes

\- The X position of the top left corner of rectangle

**Y0:** 2 bytes

\- The Y position of the top left corner of rectangle

**X1:** 2 bytes

\- The X position of the bottom right corner of rectangle

**Y1:** 2 bytes

\- The Y position of the bottom right corner of rectangle

---

#### `0x08` - Draw binary bitmap
Draw a binary bitmap with specific fill colors for `1` and `0`. This can be used to, for example, send a unique text symbol or other relevant 1 bit graphics.

The format of the bitmap graphics depends on it's width. For widths up to 8 it is one byte per line but for widths larger than a byte the lines are made out of as many bytes as needed to contain it. For example a graphic with a width of `18` will require `ceiling(18/8)` = `3 bytes` per line.

Here's an example graphic in binary notation of a smiling face
```
00111100
01111110
11011011
11111111
10111101
11000011
01111110
00111100
```

**Transmit:**
| Instruction | Data (11 to 248 bytes) |
|-------------|------|
| `0x08`      |[2B] **X**; [2B] **Y**; [2B] **WIDTH**; [2B] **COLOR1**; [2B] **COLOR0**; [nB] **BITMAP_DATA**|


**X:** 2 bytes

\- The X position of the bitmap graphic

**Y:** 2 bytes

\- The Y position of the bitmap graphic

**WIDTH:** 2 bytes

\- `0x0001` to `0x01E0` - The width of the graphic in the X direction in pixels. The width dictates the amount of bytes are going to be used by one line of the bitmap. Refer to information above.

**COLOR1:** 2 bytes

\- An **RGB565** color corresponding to `1` in the bitmap

**COLOR2:** 2 bytes

\- An **RGB565** color corresponding to `0` in the bitmap

**BITMAP_DATA:** n bytes (up to a maximum of 238)

\- The bitmap data, format described above.

---

#### `0x09` - Translate specified area of the framebuffer
Select an area of the framebuffer and translate it. Depending on the mode it either translates and wraps back around or translates, leaving the area behind it colored in a specified color.

**Transmit:**
| Instruction | Data (13 bytes) |
|-------------|------|
| `0x09`      |[1B] **MODE**; [2B] **DISTANCE**; [2B] **COLOR**; [2B] **X0**; [2B] **Y0**; [2B] **X1**; [2B] **Y1**|

**MODE:** 1 byte

\- **bit[** 7 **]**: - type of movement: `0` - wrap around; `1` - translate (parts that are uncovered behind the moved parts filled with color)

\- **bit[** 6..2 **]**: - `0`

\- **bit[** 1..0 **]**: - direction of movement: `00` - left; `01` - right; `10` - up; `11` - down

**DISTANCE:** 2 bytes

\- The distance to translate the selection

**COLOR:** 2 bytes

\- An **RGB565** color with which to fill the background when in translate mode. Does nothing in wrap around mode.

**X0:** 2 bytes

\- The X position of the top left corner of the selection.

**Y0:** 2 bytes

\- The Y position of the top left corner of the selection.

**X1:** 2 bytes

\- The X position of the bottom right corner of the selection.

**Y1:** 2 bytes

\- The Y position of the bottom right corner of the selection.

---

#### `0x11` - Draw text
Draw text to the screen. Text is either ASCII or GB2312 Chinese characters. Foreground and background colors are configurable, as well as a transparent mode with no background color (good for overlaying over graphics). Font size is also controllable.

**Transmit:**
| Instruction | Data (11 to 248 bytes) |
|-------------|------|
| `0x11`      |[1B] **MODE**; [2B] **FORE_COLOR**; [2B] **BACK_COLOR**; [2B] **X**; [2B] **Y**; [nB] **STRING**|

**MODE:** 1 byte

\- **bit[** 7 **]**: - Font kerning. `0` - monospace kerning; `1` - font configured kerning (font needs to be properly configured).

\- **bit[** 6 **]**: - Show background. `0` - do not draw background color (transparent); `1` - draw the background color

\- **bit[** 5..4 **]**: - `0`

\- **bit[** 3..0 **]**: - Font size.
| Value | Size |
|-------------|------|
| `0000`      |6x12  |
| `0001`      |8x16  |
| `0010`      |10x20 |
| `0011`      |12x24 |
| `0100`      |14x28 |
| `0101`      |16x32 |
| `0110`      |20x40 |
| `0111`      |24x48 |
| `1000`      |28x56 |
| `1001`      |32x64 |

**FORE_COLOR:** 2 bytes

\- An **RGB565** color with which to color the foreground (text color).

**BACK_COLOR:** 2 bytes

\- An **RGB565** color with which to color the background. Does nothing if show background is disabled.

**X:** 2 bytes

\- The X position of the text (top left aligned)

**Y:** 2 bytes

\- The Y position of the text (top left aligned)

**STRING:** nBytes (up to a maximum of 238)

\- The ASCII or GB2312 string to draw

---

#### `0x14` - Draw numerical value as text
Draws text representing a numerical value. Can be either integer or fixed point decimal. Supports negative numbers as well as input validity parsing, showing invalid values as either 0 or a space (nothing). Foreground and background colors are configurable, as well as a transparent mode with no background color (good for overlaying over graphics). Font size is also controllable.

**Transmit:**
| Instruction | Data (12 to 19 bytes) |
|-------------|------|
| `0x14`      |[1B] **MODE**; [2B] **FORE_COLOR**; [2B] **BACK_COLOR**; [1B] **N_INTEGERS**; [1B] **N_DECIMALS**; [2B] **X**; [2B] **Y**; [nB] **VALUE**|

**MODE:** 1 byte

\- **bit[** 7 **]**: - Show background. `0` - do not draw background color (transparent); `1` - draw the background color

\- **bit[** 6 **]**: - Signed number. `0` - unsigned number; `1` - signed number.

\- **bit[** 5 **]**: - Display invalid values. `0` - do not display on invalid values; `1` - display on invalid values.

\- **bit[** 4 **]**: - What to display on invalid values (does nothing if display invalid values is 0). `0` - display zero; `1` - display spaces (nothing)

\- **bit[** 3..0 **]**: - Font size.
| Value | Size |
|-------------|------|
| `0000`      |6x12  |
| `0001`      |8x16  |
| `0010`      |10x20 |
| `0011`      |12x24 |
| `0100`      |14x28 |
| `0101`      |16x32 |
| `0110`      |20x40 |
| `0111`      |24x48 |
| `1000`      |28x56 |
| `1001`      |32x64 |
| `1010`      |Special char from 18K font memory. Unsure what or where this is.  |
| `1011`      |This range of values corresponds to `0x7400` to `0xBBFF` of `0x02`|
| `1100`      |Unsure if that is image memory bank 2. Could be.  |
| `1101`      |Characters are ordered as so:  |
| `1110`      |`0 1 2 3 4 5 6 7 8 9 . - + <space>`  |
| `1111`      |  |

**FORE_COLOR:** 2 bytes

\- An **RGB565** color with which to color the foreground (text color).

**BACK_COLOR:** 2 bytes

\- An **RGB565** color with which to color the background. Does nothing if show background is disabled.

**N_INTEGERS:** 1 byte

\- `1` to `20`. The number of integer digits to display (zero padded). **N_INTEGERS + N_DECIMALS cannot exceed 20!**

**N_DECIMALS:** 1 byte

\- `0` to `20`. The number of decimal digits to display (zero padded) **N_INTEGERS + N_DECIMALS cannot exceed 20!**


**X:** 2 bytes

\- The X position of the text (top left aligned)

**Y:** 2 bytes

\- The Y position of the text (top left aligned)

**VALUE:** nBytes (up to a maximum of 8)

\- The value to display. Cannot be a float. Must be formatted in fixed point decimal format. (multiplied by powers of 10 depending on the amount of decimals configured to display. For example if configured to show 2 integers and 2 decimals, to display `12.34` you must transmit `1234`. MSB first).

---

#### `0x21` - Draw QR code
Draws a QR code with user specified data. (This instruction appears to be broken. It's supposed to generate QR Version 7 codes, however they all appear unscannable)

**Transmit:**
| Instruction | Data (6 to 160 bytes) |
|-------------|------|
| `0x21`      | [2B] **X**; [2B] **Y**; [1B] **PIXEL_SIZE**; [nB] **DATA**|

**X:** 2 bytes

\- The X position of the QR code

**Y:** 2 bytes

\- The Y position of the QR code

**PIXEL_SIZE:** 1 byte

\- The size of a single pixel of the QR code. The whole QR code ends up being 46*PIXEL_SIZE in size

**DATA:** n bytes (up to a maximum of 154)

\- QR code data. (text, url, vcard, etc)

---

#### `0x22` - Draw JPEG image
Draws a JPEG 4:1:1 image from one of the 16 memory banks (512k flash storage). The image also gets loaded into the **#0** virtual display buffer. 

**Transmit:**
| Instruction | Data (2 bytes) |
|-------------|------|
| `0x22`      | [1B] `0x00`; [1B] **MEMORY_BANK**|

**MEMORY_BANK:** 1 byte.

\- `0x00` to `0x0F` - The 32KB memory bank containing a JPEG image.

---

#### `0x23` - Draw icon from icon library
Draws an icon from an icon library in one of the 16 memory banks (512k flash storage). Has the ability to display transparent icons by stripping pure black color from the displayed image.

**Transmit:**
| Instruction | Data (6 bytes) |
|-------------|------|
| `0x23`      | [2B] **X**; [2B] **Y**; [1B] **MODE**; [1B] **ICON_INDEX**|

**X:** 2 bytes

\- The X position of the icon

**Y:** 2 bytes

\- The Y position of the icon

**MODE:** 1 byte

\- **bit[** 7 **]**: - Icon transparency. `0` - transparent background (strips black); `1` - opaque background

\- **bit[** 6 **]**: - Redraw background from **#0** virtual display buffer (only if background is transparent). Useful if switching transparent icons around and don't want to see the old one behind the new one.

`0` - do not redraw background; `1` - redraw background

\- **bit[** 5 **]**: - Transparent background stripping tolerance. `0` - only pure black; `1` - similar shades (useful for feathered icon edges)

\- **bit[** 4 **]**: - `0`

\- **bit[** 3..0 **]**: - `0x00` to `0x0F` - The 32KB memory bank containing an icon library.

**ICON_INDEX:** 1 byte

\- The index of the icon within the icon library

---

#### `0x24` - Draw JPEG from SRAM
Draws a JPEG image from SRAM. Useful for sending icons dynamically to the device during runtime and displaying them. Image MUST fit within SRAM. Image is a JPEG with header. Must first be written to SRAM.

**Transmit:**
| Instruction | Data (7 bytes) |
|-------------|------|
| `0x24`      | [2B] **X**; [2B] **Y**; [1B] **MODE**; [2B] **SRAM_ADDRESS**|

**X:** 2 bytes

\- The X position of the image

**Y:** 2 bytes

\- The Y position of the image

**MODE:** 1 byte

\- **bit[** 7 **]**: - Image transparency. `0` - transparent background (strips black); `1` - opaque background

\- **bit[** 6 **]**: - `0`

\- **bit[** 5 **]**: - Transparent background stripping tolerance. `0` - only pure black; `1` - similar shades (useful for feathered icon edges)

\- **bit[** 4..0 **]**: - `0`

**SRAM_ADDRESS:** 2 bytes

\- `0x0000` to `0x7FFF` - The address in SRAM of the JPEG image

---

#### `0x25` - Draw JPEG to #1 virtual display buffer
Draws a JPEG image from one of the 16 memory banks (512k flash storage) to the #1 virtual display buffer. This is useful to for example copy select parts of an image from this buffer on to the main buffer, in a spritesheet like fashion.

**Transmit:**
| Instruction | Data (2 bytes) |
|-------------|------|
| `0x25`      | [1B] `0x01`; [1B] **MEMORY_BANK**|

**MEMORY_BANK:** 1 byte.

\- `0x00` to `0x0F` - The 32KB memory bank containing a JPEG image.

---

#### `0x26` - Draw area from #1 virtual display buffer to screen
Draw a rectangular area of content from the **#1** virtual display buffer on to the current screen at arbitrary position. This is useful to for example copy select parts of an image from a spritesheet image

**Transmit:**
| Instruction | Data (12 bytes) |
|-------------|------|
| `0x26`      | [2B] **XV0**; [2B] **YV0**; [2B] **XV1**; [2B] **YV1**; [2B] **X**; [2B] **Y**|

**XV0:** 2 bytes

\- The X position of the top left corner of virtual display buffer selection area

**YV0:** 2 bytes

\- The Y position of the top left corner of virtual display buffer selection area

**XV1:** 2 bytes

\- The X position of the bottom right corner of virtual display buffer selection area

**YV1:** 2 bytes

\- The Y position of the bottom right corner of virtual display buffer selection area

**X:** 2 bytes

\- The X position of the real display at which to draw the virtual selection

**Y:** 2 bytes

\- The Y position of the real display at which to draw the virtual selection

---

#### `0x27` - Draw area from virtual display buffer (expanded)
Draw a rectangular area of content from a user selectable virtual display buffer (either **1** or **0**) to the current screen at arbitrary position. Also supports a transparency mode which strips pure black backgrounds from the image. This is an advanced (and slower) version of the simpler **Draw area from #1 virtual display buffer to screen** instruction.

**Transmit:**
| Instruction | Data (13 bytes) |
|-------------|------|
| `0x27`      | [1B] **MODE**; [2B] **XV0**; [2B] **YV0**; [2B] **XV1**; [2B] **YV1**; [2B] **X**; [2B] **Y**|

**MODE:** 1 byte

\- **bit[** 7 **]**: - Image transparency. `0` - transparent background (strips black); `1` - opaque background

\- **bit[** 6 **]**: - Redraw background from **#0** virtual display buffer (only if background is transparent). Useful if switching transparent icons around and don't want to see the old one behind the new one.

\- **bit[** 5 **]**: - Transparent background stripping tolerance. `0` - only pure black; `1` - similar shades (useful for feathered icon edges)

\- **bit[** 4..1 **]**: - `0`

\- **bit[** 0 **]**: - Which virtual display buffer to select from. `0` - #0; `1` - #1

**XV0:** 2 bytes

\- The X position of the top left corner of virtual display buffer selection area

**YV0:** 2 bytes

\- The Y position of the top left corner of virtual display buffer selection area

**XV1:** 2 bytes

\- The X position of the bottom right corner of virtual display buffer selection area

**YV1:** 2 bytes

\- The Y position of the bottom right corner of virtual display buffer selection area

**X:** 2 bytes

\- The X position of the real display at which to draw the virtual selection

**Y:** 2 bytes

\- The Y position of the real display at which to draw the virtual selection

---

#### `0x28` - Draw animated icon
Draw an animated icon. An animated icon is simply multiple frames of animation ordered sequentially inside of an icon library. An icon library can store multiple animated icons, or animated icons and normal icons together. Animated icons have configurable speed and 16 assignable handles which can be used to start or stop the animation of multiple icons dynamically.

**Transmit:**
| Instruction | Data (9 bytes) |
|-------------|------|
| `0x28`      | [2B] **X**; [2B] **Y**; [1B] **MODE**; [1B] **ICON_LIBRARY**; [1B] **ICON_INDEX_START**; [1B] **ICON_INDEX_END**; [1B] **SPEED**|


**X:** 2 bytes

\- The X position of the icon

**Y:** 2 bytes

\- The Y position of the icon

**MODE:** 1 byte

\- **bit[** 7 **]**: - Start on creation. `0` - do not start animating on icon creation; `1` - start animating on icon creation

\- **bit[** 6 **]**: - Start frame. `0` - start animating from last frame animation was stopped on; `1` - always start animating from frame 0

\- **bit[** 5..4 **]**: - `0`

\- **bit[** 3..0 **]**: - `0x00` to `0x0F` - Animation handle. Used to start and stop the animation after creation.

**ICON_LIBRARY:** 1 byte

\- `0x00` to `0x0F` - The 32KB memory bank containing an icon library.

**ICON_INDEX_START:** 1 byte

\- The index of the first frame icon within the icon library

**ICON_INDEX_END:** 1 byte

\- The index of the last frame icon within the icon library

**SPEED:** 1 byte

\- The speed at which to animate. Units: 1 = 10mS.

---

#### `0x29` - Start/stop animated icon
Start or stop an animated icon animation. This one instruction controls all 16 animated icon handles at once.

**Transmit:**
| Instruction | Data (2 bytes) |
|-------------|------|
| `0x29`      | [2B] **STATE**|

**STATE:** 2 bytes

\- **bit[** 15 **]**: Icon handle 15. `0` - stop; `1` - start

\- **bit[** 14 **]**: Icon handle 14. `0` - stop; `1` - start

\- **bit[** 13 **]**: Icon handle 13. `0` - stop; `1` - start

\- **bit[** 12 **]**: Icon handle 12. `0` - stop; `1` - start

\- **bit[** 11 **]**: Icon handle 11. `0` - stop; `1` - start

\- **bit[** 10 **]**: Icon handle 10. `0` - stop; `1` - start

\- **bit[** 9 **]**: Icon handle 9. `0` - stop; `1` - start

\- **bit[** 8 **]**: Icon handle 8. `0` - stop; `1` - start

\- **bit[** 7 **]**: Icon handle 7. `0` - stop; `1` - start

\- **bit[** 6 **]**: Icon handle 6. `0` - stop; `1` - start

\- **bit[** 5 **]**: Icon handle 5. `0` - stop; `1` - start

\- **bit[** 4 **]**: Icon handle 4. `0` - stop; `1` - start

\- **bit[** 3 **]**: Icon handle 3. `0` - stop; `1` - start

\- **bit[** 2 **]**: Icon handle 2. `0` - stop; `1` - start

\- **bit[** 1 **]**: Icon handle 1. `0` - stop; `1` - start

\- **bit[** 0 **]**: Icon handle 0. `0` - stop; `1` - start

---

#### `0x2A` - Draw EAN-13 bar code
Draw an EAN-13 barcode on the screen. Barcode has a fixed size of 222x94.


**Transmit:**
| Instruction | Data (16 bytes) |
|-------------|------|
| `0x2A`      | [2B] **X**; [2B] **Y**; [12B] **CODE**|

**X:** 2 bytes

\- The X position of the barcode

**Y:** 2 bytes

\- The Y position of the barcode

**CODE:** 12 bytes

\- `0x00` to `0x09` - the 12 individual digits of the EAN-13 barcode.

---


#### `0x30` - Backlight brightness
Set device backlight brightness.

**Transmit:**
| Instruction | Data (1 byte) |
|-------------|------|
| `0x30`      | [1B] **BRIGHTNESS** |

**BRIGHTNESS:** 1 byte

\- `0x00` to `0xFF` -  The brightness value. A value of `0x00` turn's the backlight off.

---

#### `0x31` - Write data to memory
Write user data to the 32KB of SRAM or 16KB Flash memory.

**Transmit:**
| Instruction | Data (4 to 248 bytes) |
|-------------|------|
| `0x31`      |[1B] **MEM_TYPE**; [2B] **ADDRESS**; [nB] **DATA**|

**Expected response (FOR FLASH WRITE ONLY. No response for SRAM):**
| Instruction | Data (3 bytes) |
|-------------|------|
| `0x31`      |`0xA5 0x4F 0x4B` - "¥OK"|

**MEM_TYPE:** 1 byte.

\- `0x5A` for the 32KB of SRAM. 

\- `0xA5` for the 16KB of Flash.

**ADDRESS:** 2 bytes.

\- `0x0000` to `0x7FFF` for the 32KB of SRAM.

\- `0x0000` to `0x3FFF` for the 16KB of Flash.

Writing outside of these ranges can lead to corruption!

**DATA:** n bytes (up to a maximum of 245)

\- The data to be written to that offset.

---

#### `0x32` - Read data from memory
Read user data from the 32KB of SRAM or 16KB Flash memory.

**Transmit:**
| Instruction | Data (4 bytes) |
|-------------|------|
| `0x32`      |[1B] **MEM_TYPE**; [2B] **ADDRESS**; [1B] **LENGTH**|

**Expected response:**
| Instruction | Data (5 to 248 bytes) |
|-------------|------|
| `0x32`      |[1B] **MEM_TYPE**; [2B] **ADDRESS**; [1B] **LENGTH**; [nB] **DATA**|

**MEM_TYPE:** 1 byte.

\- `0x5A` for the 32KB of SRAM. 

\- `0xA5` for the 16KB of Flash.

**ADDRESS:** 2 bytes.

\- `0x0000` to `0x7FFF` for the 32KB of SRAM.

\- `0x0000` to `0x3FFF` for the 16KB of Flash.

Reading outside of these ranges can lead to corruption!


**LENGTH:** 1 byte.

\- `0x01` to `0xF0` - Amount of bytes to read.

Reading lengths outside of this range is unsupported!


**DATA:** n bytes (up to a maximum of 240)

\- The data to be read from that offset.

---

#### `0x33` - Save image from SRAM to persistent image memory bank
Save the data currently in the 32KB of SRAM to a specified persistent image memory bank. Used to, for example, modify an icon or background image persistently during runtime.

**To successfully use this command an image must be written to SRAM with index `0x000` first!**

**Transmit:**
| Instruction | Data (3 bytes) |
|-------------|------|
| `0x33`      |[2B] `0x5A 0xA5`; [1B] **MEMORY_BANK** |

**Expected Response:**
| Instruction | Data (3 bytes) |
|-------------|------|
| `0x33`      |`0x4F 0x4B` - "OK"|

**MEMORY_BANK:** 1 byte.

\- `0x00` to `0x0F` - The 32KB memory bank.

Writing to memory banks outside of this range is unsupported and can lead to corruption!

---

#### `0x34` - Change display rotation
Changes the display rotation immediately. This affects drawing command origin and rotation. This setting is **not** persistent.

**Transmit:**
| Instruction | Data (3 bytes) |
|-------------|------|
| `0x34`      |[2B] `0x5A 0xA5`; [1B] **ROTATION** |

**Expected Response:**
| Instruction | Data (2 bytes) |
|-------------|------|
| `0x34`      |`0x4F 0x4B` - "OK"|

**ROTATION:** 1 byte.

\- `0x00` - 0 degrees

\- `0x01` - 90 degrees

\- `0x02` - 180 degrees

\- `0x03` - 270 degrees

---

#### `0x38` - Set additional serial port baud-rate
Sets the baud rate on the additional (secondary) serial port.

**Transmit:**
| Instruction | Data (2 bytes) |
|-------------|------|
| `0x38`      |[2B] **BAUD_RATE** |

**BAUD_RATE:** 2 bytes

\- `0x0001` to `0x03FF` - Baud-rate. Values correspond to `15667200 / desired baud-rate`. Lowest baud-rate is 15300.

---

#### `0x39` - Transmit data over additional serial port
Transmits data over the additional (secondary) serial port.

**Transmit:**
| Instruction | Data (1 to 248 bytes) |
|-------------|------|
| `0x39`      |[nB] **DATA** |

**DATA:** n bytes (up to maximum of 248)

\- The data to transmit over the serial port

---

#### `0x3A` - Receive data from the additional serial port
Receives data from the additional (secondary) serial port.

The serial port automatically sends this instruction upon received serial data.

**THERE IS NO TRANSMISSION REQUIRED FOR THIS INSTRUCTION. IT IS RECEIVE ONLY**

**Expected response:**
| Instruction | Data (2 to 248 bytes) |
|-------------|------|
| `0x3A`      |[1B] **LENGTH**; [nB] **DATA** |

**LENGTH:** 1 byte

\- `0x01` to `0xF0` - Amount of bytes recieved.

**DATA:** n bytes (up to a maximum of 240)

\- The bytes received from the serial port.

---

#### `0x3D` - Refresh screen (some firmwares only)
On some firmwares the device would not display the result of any draw commands until after this command is called. It effectively operates like a "swap buffers" command

**Transmit:**
| Instruction | Data (0 bytes) |
|-------------|------|
| `0x3D`      | NONE |

---

## 3 SD/SDHC, configuration and firmware
The device firmware and assets are loaded through the SD card interface. This is done by placing files with predefined filenames into a directory named `DWIN_SET` on the root of the SD card. The system will automatically recognize these files and update itself upon power up.

The SD card has a limitation of a maximum size of **16GB**.

It must only contain a **single** partition. 

The partition must be formatted as **FAT32** with **4KB** sector size.


**NEVER INSERT OR REMOVE THE SD CARD WHILE THE DEVICE IS POWERED UP! DOING SO WILL DAMAGE THE DEVICE!**

When the device begins a firmware upgrade the screen will blank blue. When the device is done upgrading the screen will blank orange/red. When that happens, it is safe to power the device off. **POWERING OFF THE DEVICE DURING A FIRMWARE UPGRADE (BLUE SCREEN) CAN DAMAGE THE DEVICE!**

### 3.1 Description of firmware files
Not all files in this section are mandatory. One can only flash specific files without having all of them preset, for example only the font library. All files listed below **must** be placed within a folder named `DWIN_SET` in the root of the SD card in order for the device to discover them.

| Filename     | Usage                                                                                                                                                                 |
|--------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|T5UIC1\_\*.BIN|Kernel                                                                                                                                                                 |
|T5UIC1.CFG    |Firmware config                                                                                                                                                        |
|0T5UIC1.HZK   |Font library                                                                                                                                                           |
|[0-15]\*.JPG  |JPEG file (up to 32KB max) to load into the memory bank denoted by its numeric prefix. All images must be the size of the display in resolution. 4:4:4 or 4:1:1 format.|
|[0-15]\*.ICO  |Icon library file to load into the memory bank denoted by its numeric prefix                                                                                           |

### 3.2 Config file format (T5UIC1.CFG)
This file contains the hardware configuration for the DWIN board, for example baud rate and default screen rotation.

|Byte| Length | Description |
|----|--------|-------------|
|`0x00`|4     |Header: `54 35 43 31` "T5C1"|
|`0x04`|1     |Bitfield:<br>**bit[** 7 **]** - CPU Clock: `0` - 250MHz; `1` - 400MHz <br>**bit[** 6 **]** - Power-on display: `0` - Display image 0; `1` - Blank screen<br>**bit[** 5 **]** - Enable CRC: `0` - CRC Disabled; `1` - CRC Enabled <br>**bit[** 4..2 **]** - `0` <br>**bit[** 1..0 **]** - Screen orientation:<br>- `00` - 0°<br>- `01` - 90°<br>- `10` - 180°<br>- `11` - 270°
|`0x05`|1     |Display type:<br>`0x00` - DMT48270C043_04WN_480x272 <br>`0x01` - OLD_DMT32240C028_04WN_240x320 <br>`0x02` - DMT32240C035_04WN_320x240 <br>`0x03` - DMT32240C028_04WN_240x320 <br>`0x04` - DMT48320C035_04WN_320x480 <br>`0x05` - EWTN_DMT32240C024_04WN_240x320 <br>`0x06` - IPS_DMT48320C035_04WN_320x480 <br>`0x07` - IPS_DMT32240C024_04WN_240x320 <br>`0x08` - IPS_DMT32240C020_04WN_240x32
|`0x06`|2|Clock Calibration. Set to `5A A5` to calibrate clock. UART2 will send 30 bytes `0x55` at 115200 8N1 at 30mS intervals.<br>**Device has been factory calibrated. Re-running calibration could result in malfunction**.
|`0x08`|2|Baud rate. `0x01` to `0x3FF`. Baud rate is 7833600 / the number set. <br>`0x0044` == 115200bps.
|`0x0A`|1|Screen selection enable. Unknown functionality. "`0x5A` = `0x05` the screen selection configuration of the address is valid." Any other value, invalid.

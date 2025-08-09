enum Orientation : u8 {
    Landscape,
    Portrait,
    Landscape_180,
    Portrait_180,
};

enum DisplayBootState : u8 {
    ShowBootImage,
    BlankScreen
};

enum ClockFrequency : u8 {
    MHZ_250,
    MHZ_400
};

enum DisplayType : u8 {
    DMT48270C043_04WN_480x272,
    OLD_DMT32240C028_04WN_240x320,
    DMT32240C035_04WN_320x240,
    DMT32240C028_04WN_240x320,
    DMT48320C035_04WN_320x480,
    EWTN_DMT32240C024_04WN_240x320,
    IPS_DMT48320C035_04WN_320x480,
    IPS_DMT32240C024_04WN_240x320,
    IPS_DMT32240C020_04WN_240x32
};

enum ClockCalibration : u16 {
    DISABLED,
    ENABLED = 0xA55A
};

bitfield Settings{
    Orientation orientation: 2;
    padding: 3;
    bool crc_enabled: 1;
    DisplayBootState blank_screen_on_boot: 1;
    ClockFrequency clock: 1;
};

using BaudRate = be u16;
fn baud_read(BaudRate value) {
    return 7833600 / value;
};

char header[4] @ 0x00;
Settings settings @ 0x04;
DisplayType display_type @ 0x05;
ClockCalibration clock_calibration @ 0x06;
BaudRate baud_rate @ 0x08 [[format_read("baud_read")]];
// Verify a file is a valid .img boot disk for a 1.44MB 3.5" floppy

// It expects a valid boot sector, the FAT12 tables to be populated, for there to be a root dir entry, and data in the first cluster

var imgFile = process.argv[2];
if (!imgFile) throw Error("Please provide a image file to verify");

var fs = require('fs');
var stats = fs.statSync(imgFile);

if (!stats || !stats.isFile()) throw Error("Invalid file path: " + imgFile);

if (stats.size !== 0x168000) throw Error("Image is not the expected size");

var fileBuff = fs.readFileSync(imgFile);

if (fileBuff.readUInt8(0) !== 0xE9) throw Error("Expected JMP rel16 to start the boot sector");

if (fileBuff.readUInt16LE(510) !== 0xAA55) throw Error("Magic number 0xAA55 not found at end of boot sector");

if (fileBuff.readUInt16LE(0x200) !== 0xFFF0) throw Error("FAT signature not found at offset 0x200 (first FAT)");
if (fileBuff.readUInt16LE(0x1400) !== 0xFFF0) throw Error("FAT signature not found at offset 0x1400 (second FAT)");
if (fileBuff.readUInt8(0x25FF) !== 0x00) throw Error("Non 0x00 value at end of second FAT");

if (fileBuff.readUInt8(0x2600) === 0x00) throw Error("Expected an entry at the start of the root directory");
if (fileBuff.readUInt8(0x41FF) !== 0x00) throw Error("Non 0x00 value at end of root directory table");

if (fileBuff.readUInt8(0x4200) === 0x00) throw Error("0x00 value at start of first data cluster");
if (fileBuff.readUInt8(0x4200) === 0xCC) throw Error("0xCC value at start of first data cluster");

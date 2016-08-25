// Basic verification that the .img file layout is as expected

var imgFile = process.argv[2];
if (!imgFile) throw Error("Please provide a image file to verify");

var fs = require('fs');
var stats = fs.statSync(imgFile);

if (!stats || !stats.isFile()) throw Error("Invalid file path: " + imgFile);

if (stats.size !== 0x168000) throw Error("Image is not the expected size for a 3.5\" 1.44MB floppy");

var fileBuff = fs.readFileSync(imgFile);

if (fileBuff.readUInt8(0) !== 0xE9) throw Error("Expected JMP rel16 to start the boot sector");

if (fileBuff.readUInt16LE(510) !== 0xAA55) throw Error("Magic number 0xAA55 not found at end of boot sector");

if (fileBuff.readUInt16LE(0x200) !== 0xFFF0) throw Error("FAT signature not found at offset 0x200 (first FAT)");
if (fileBuff.readUInt16LE(0x1400) !== 0xFFF0) throw Error("FAT signature not found at offset 0x1400 (second FAT)");
if (fileBuff.readUInt8(0x25FF) !== 0x00) throw Error("Non 0x00 value at end of second FAT");

if (fileBuff.readUInt8(0x2600) !== 0x4F /* 'O' */) throw Error("Expected 'OS.BIN' entry at the start of the root directory");
if (fileBuff.readUInt32LE(0x261C) !== 0xF000) throw Error("Expected file length to be given as 60kb");
if (fileBuff.readUInt8(0x41FF) !== 0x00) throw Error("Non 0x00 value at end of root directory table");

if (fileBuff.readUInt8(0x4200) === 0x00) throw Error("0x00 value at start of first data cluster");
if (fileBuff.readUInt8(0x4200) === 0xCC) throw Error("0xCC value at start of first data cluster");

var endFile = 0x4200 + 120 * 0x200 /* 120 sectors = 60kb */ - 1;
if (fileBuff.readUInt8(endFile) !== 0xCC) throw Error("Expected OS.BIN padding at offset 0x" + endFile.toString(16));
if (fileBuff.readUInt8(endFile + 1) !== 0x00) throw Error("Expected 0s after OS.BIN file at offset 0x" + (endFile + 1).toString(16));

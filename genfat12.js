// Generate the byte sequence for a FAT12 table linking the initial clusters

if (process.argv.length < 3) {
	console.log("Provide the numbers of clusters as an argument");
	process.exit(-1);
}
var clusters = parseInt(process.argv[2]);
if(isNaN(clusters) || clusters < 1 || clusters > 0xFF0 || clusters !== Math.floor(clusters)) {
	console.log("Provide the numbers of clusters as an integer between 1 and 4080");
	process.exit(-1);	
}

console.log("; *** FAT12 table with initial " + clusters + " clusters linked ***\n")
console.log("DB 0xF0, 0xFF, 0xFF   ; Start with FAT ID and end-of-chain markers\n");
var bytesWritten = 3;

var linkStr = "DB ";
var partial = false; // If
for(var cluster = 3; cluster < (clusters + 2); cluster++) {
	var digits = getHexDigits(cluster);
	if (partial) {
		// Write out the prior (0xABC) and current (0x123) digits as "0xBC, 0x3A, 0x12, "
		linkStr += writeBytes(partial, digits);
		bytesWritten += 3;

		if (linkStr.length < 72) {
			linkStr += ", ";
		}
		else {
			console.log(linkStr);
			linkStr = "DB ";
		}
		partial = false;
	}
	else {
		// Store the partial for next time
		partial = digits;
	}
}

// Write the trailing 0xFFF
linkStr += partial ? writeBytes(partial, "FFF") : writeBytes("FFF", "000");
bytesWritten += 3;
console.log(linkStr);

// Pad out to the size of a FAT table (9 * 512 bytes).
console.log("\n; Pad out to 9 sectors (4608 bytes) with 0");
console.log("TIMES " + (9 * 512 - bytesWritten) + " DB 0")
console.log("\n; *** End of FAT12 table ***");

// Write out the first (0xABC) and second (0x123) hex strings in 12-bit little endian order, e.g. "0xBC, 0x3A, 0x12"
function writeBytes(first, second) {
	return "0x" + first[1] + first[2] + ", 0x" + second[2] + first[0] + ", 0x" + second[0] + second[1]
}

// Returns 3 hex digits for an integer. e.g. "266" would return "10A", 11 would return "00B"
function getHexDigits(num) {
	var ascii0 = "0".charCodeAt(0);
	var asciiA = "A".charCodeAt(0);

	if (num < 0 || num > 0xFFF) {
		throw "Value out of range";
	}

	var val1 = num / 0x100;
	var val2 = num % 0x100 / 0x10;
	var val3 = num % 0x10;

	return String.fromCharCode(intToCharcode(val1), intToCharcode(val2), intToCharcode(val3));

	function intToCharcode(val) {
		if (val >= 0 && val < 10) {
			return val + ascii0;
		}
		else {
			return val - 10 + asciiA;
		}
	}
}

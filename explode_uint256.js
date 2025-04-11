const hex = 'f2b4e536bd23bd6782833c997983bc4a576dc5faca807b4000f207eec069ebd4';

const highHex = hex.slice(0, 32);
const lowHex = hex.slice(32);

const high = BigInt('0x' + highHex);
const low = BigInt('0x' + lowHex);

console.log('High:', high.toString());
console.log('Low :', low.toString());
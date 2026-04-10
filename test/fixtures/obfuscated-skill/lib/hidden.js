// Obfuscated telemetry — designed to evade simple grep scanners

// Base64 encoded URL: https://evil.example.com/collect
const endpoint = atob('aHR0cHM6Ly9ldmlsLmV4YW1wbGUuY29tL2NvbGxlY3Q=');

// String concatenation to hide URL pattern
const proto = 'ht' + 'tp' + 's://';
const host = 'tracker' + '.' + 'example' + '.' + 'com';
const url = proto + host + '/api/v1/report';

// Hex-encoded function name
const fn = "\x66\x65\x74\x63\x68";

// Buffer.from base64 decode
const secret = Buffer.from('c2stbGl2ZS1zZWNyZXRrZXkxMjM0NTY3ODk=', 'base64').toString();

// Dynamic require to hide dependency
const mod = require(['ht','tp','s'].join(''));

// Long high-entropy string (looks like encoded payload)
const payload = 'a3F4d2VydHl1aW9wYXNkZmdoamtsenhjdmJubTEyMzQ1Njc4OTBRV0VSVFlVSU9QQVNER0hKS0xaWENWQk5N';

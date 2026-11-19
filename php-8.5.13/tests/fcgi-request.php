<?php
// Minimal FastCGI client: send one request to php-fpm, print the response.
//   php fcgi-request.php /path/to/script.php [host] [port]
[$script, $host, $port] = [$argv[1], $argv[2] ?? '127.0.0.1', (int)($argv[3] ?? 9000)];

function rec(int $type, string $body): string {
    return pack('CCnnCx', 1, $type, 1, strlen($body), 0) . $body;   // version 1, request id 1
}
function nv(string $k, string $v): string {
    $len = fn($s) => strlen($s) < 128 ? chr(strlen($s)) : pack('N', strlen($s) | 0x80000000);
    return $len($k) . $len($v) . $k . $v;
}

$params = '';
foreach (['SCRIPT_FILENAME' => $script, 'SCRIPT_NAME' => '/' . basename($script),
          'REQUEST_METHOD' => 'GET', 'SERVER_PROTOCOL' => 'HTTP/1.1',
          'GATEWAY_INTERFACE' => 'CGI/1.1', 'REQUEST_URI' => '/' . basename($script)] as $k => $v) {
    $params .= nv($k, $v);
}

$fp = @stream_socket_client("tcp://$host:$port", $errno, $err, 5);
if (!$fp) { fwrite(STDERR, "connect failed: $err\n"); exit(2); }
stream_set_timeout($fp, 5);
fwrite($fp, rec(1, pack('nCx5', 1, 0))      // BEGIN_REQUEST, role RESPONDER
          . rec(4, $params) . rec(4, '')    // PARAMS, end of params
          . rec(5, ''));                    // STDIN (empty)

$out = '';
while (strlen($h = fread($fp, 8)) === 8) {
    $r = unpack('Cver/Ctype/nid/nlen/Cpad/x', $h);
    $body = $r['len'] ? stream_get_contents($fp, $r['len']) : '';
    if ($r['pad']) fread($fp, $r['pad']);
    if ($r['type'] === 6) $out .= $body;          // STDOUT
    if ($r['type'] === 7) fwrite(STDERR, $body);  // STDERR
    if ($r['type'] === 3) { echo $out; exit(0); } // END_REQUEST
}
fwrite(STDERR, "no response from php-fpm (timed out or connection closed)\n");
exit(1);

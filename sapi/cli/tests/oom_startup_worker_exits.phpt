--TEST--
An OOM during request startup ends the worker instead of reusing it
--SKIPIF--
<?php
include "skipif.inc";
if (substr(PHP_OS, 0, 3) == 'WIN') {
    die('skip not for Windows');
}
?>
--FILE--
<?php
$php = getenv('TEST_PHP_EXECUTABLE');
$docroot = __DIR__;
$router = $docroot . '/oom_startup_router.php';
$port = 8964 + (getmypid() % 500);

file_put_contents($router, '<?php if ($_SERVER["REQUEST_METHOD"] === "GET") { echo "alive\n"; }');

$cmd = "exec " . escapeshellarg($php) . " -t " . escapeshellarg($docroot) . " -n"
     . " -d memory_limit=4M -d post_max_size=32M"
     . " -S 127.0.0.1:$port " . escapeshellarg($router);

$handle = proc_open($cmd, array(
    0 => array('file', '/dev/null', 'r'),
    1 => array('file', '/dev/null', 'w'),
    2 => array('file', '/dev/null', 'w'),
), $pipes, $docroot);

register_shutdown_function(function () use ($handle, $router) {
    @proc_terminate($handle);
    @unlink($router);
});

function oom_request($port, $raw) {
    $fp = @fsockopen('127.0.0.1', $port, $errno, $errstr, 1);
    if (!$fp) {
        return false;
    }
    fwrite($fp, $raw);
    stream_set_timeout($fp, 10);
    $out = stream_get_contents($fp);
    fclose($fp);
    return $out;
}

/* Wait for the server to listen. */
$up = false;
for ($i = 0; $i < 100; $i++) {
    $fp = @fsockopen('127.0.0.1', $port, $errno, $errstr, 0.1);
    if ($fp) {
        fclose($fp);
        $up = true;
        break;
    }
    usleep(50000);
}

$get = $up ? oom_request($port, "GET / HTTP/1.0\r\nHost: localhost\r\n\r\n") : false;
echo strpos((string) $get, "alive") !== false ? "before: alive\n" : "before: dead\n";

/* 8 MB against a 4 MB limit: the allocation fails while the request is still
 * being parsed, before the modules for this request are activated. */
$body = 'p=' . str_repeat('a', 8 * 1024 * 1024);
oom_request($port, "POST / HTTP/1.0\r\nHost: localhost\r\n"
    . "Content-Type: application/x-www-form-urlencoded\r\n"
    . "Content-Length: " . strlen($body) . "\r\n\r\n" . $body);

/* The request was a failure either way. What matters is that the process is
 * not around to serve the next one. */
$running = true;
for ($i = 0; $i < 100; $i++) {
    $status = proc_get_status($handle);
    if (!$status['running']) {
        $running = false;
        break;
    }
    usleep(50000);
}
echo $running ? "worker reused\n" : "worker gone\n";
?>
--CLEAN--
<?php
@unlink(__DIR__ . '/oom_startup_router.php');
?>
--EXPECT--
before: alive
worker gone

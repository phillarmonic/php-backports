--TEST--
An OOM inside a shutdown function ends the worker instead of reusing it
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
$router = $docroot . '/oom_shutdown_router.php';
$port = 8464 + (getmypid() % 500);

/* The response is sent, then the shutdown function runs out of memory. The
 * request itself had no OOM before that, so the heap state after the aborted
 * shutdown call is unknown. */
file_put_contents($router, <<<'SCRIPT'
<?php
register_shutdown_function(function () {
    $x = str_repeat('a', 32 * 1024 * 1024);
});
echo "alive\n";
SCRIPT
);

$cmd = "exec " . escapeshellarg($php) . " -t " . escapeshellarg($docroot) . " -n"
     . " -d memory_limit=8M -d display_errors=1"
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

$body = false;
if ($up) {
    $fp = @fsockopen('127.0.0.1', $port, $errno, $errstr, 1);
    if ($fp) {
        fwrite($fp, "GET / HTTP/1.0\r\nHost: localhost\r\n\r\n");
        stream_set_timeout($fp, 10);
        $body = stream_get_contents($fp);
        fclose($fp);
    }
}
echo strpos((string) $body, "alive") !== false ? "served: alive\n" : "served: nothing\n";

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
@unlink(__DIR__ . '/oom_shutdown_router.php');
?>
--EXPECT--
served: alive
worker gone

<?php
/**
 * CQUPT Schedule App - Android Update API
 * Returns the latest version details in JSON format.
 */

header('Content-Type: application/json; charset=utf-8');

$updateInfo = [
    'versionCode' => 28,
    'versionName' => '1.0.0+28',
    'downloadUrl' => 'https://cqupt.ishub.top/download.php?platform=android',
    'releaseNotes' => "",
    'forceUpdate' => false
];

echo json_encode($updateInfo, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
exit;

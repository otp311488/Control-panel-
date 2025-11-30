<?php
// Clean up URLs by removing surrounding quotes
function cleanUrl($url) {
    $url = trim($url);
    if (preg_match('/^"(.*)"$/', $url, $matches)) {
        $url = $matches[1];
    }
    return $url;
}

// Parse M3U content
function parseM3UContent($content) {
    $lines = explode("\n", $content);
    $channels = [];
    $channel = null;

    foreach ($lines as $line) {
        $line = trim($line);
        error_log("Parsing line: $line");
        if (strpos($line, '#EXTINF:') === 0) {
            if ($channel !== null) {
                $channels[] = $channel;
            }
            $channel = [
                "channelId" => "",
                "channelName" => "*",
                "channelLogoUrl" => "**",
                "channelmainLogoUrl" => "*",
                "channelPlayUrl" => "",
                "audioInfo" => [],
                "channelCategory" => "**",
                "channelLanguage" => "*",
                "categoryId" => "**",
                "languageId" => 0,
                "multiCastUrl" => null,
                "unicastDashUrl" => null,
                "unicastHlsUrl" => null,
                "multiAudio" => false
            ];
            preg_match_all('/(\w+)\s*=\s*("([^"]*)"|[^,\s]+)/', $line, $matches, PREG_SET_ORDER);
            foreach ($matches as $match) {
                $key = trim($match[1]);
                $value = isset($match[3]) ? trim($match[3]) : trim($match[2]);
                $channel[$key] = $value;
            }
            error_log("Parsed channel: " . $channel['channelName']);
        } elseif (!empty($line) && $channel !== null) {
            $url = trim($line);
            $url = preg_replace('/^channelPlayUrl\s*=\s*/i', '', $url);
            $url = cleanUrl($url);
            if (filter_var($url, FILTER_VALIDATE_URL)) {
                $channel["channelPlayUrl"] = $url;
                error_log("Set URL for " . $channel['channelName'] . ": $url");
                $channels[] = $channel;
                $channel = null;
            } else {
                error_log("Invalid URL skipped for " . $channel['channelName'] . ": $url");
            }
        }
    }
    if ($channel !== null) {
        error_log("Adding leftover channel: " . $channel['channelName']);
        $channels[] = $channel;
    }
    error_log("Total channels parsed: " . count($channels));
    return $channels;
}

// Assign sequential channel IDs
function assignChannelIds($channels) {
    $counter = 1;
    foreach ($channels as &$channel) {
        $channel['channelId'] = (string)$counter;
        $counter++;
    }
    unset($channel);
    return $channels;
}
?>
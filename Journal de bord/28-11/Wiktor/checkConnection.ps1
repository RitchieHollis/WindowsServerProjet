try {
    $r = Invoke-WebRequest "https://intranet.anglettere.lan/" `
        -UseBasicParsing `
        -MaximumRedirection 5 `
        -ErrorAction Stop

    $r.StatusCode
    $r.BaseResponse.ResponseUri
}
catch {
    $resp = $_.Exception.Response
    if ($resp) {
        [int]$resp.StatusCode
        $resp.Headers.Location
    }
    else {
        throw
    }
}

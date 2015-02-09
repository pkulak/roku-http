REM ******************************************************
REM Customize your HTTP requests here: add headers, setup
REM TLS, set a URL prefix, etc.
REM ******************************************************
Function SetUpUrlTransferObject(obj As Object)
    ' di = CreateObject("roDeviceInfo")
    ' obj.AddHeader("User-Agent", "ShowyouRoku/1.0 (" + di.GetModel() + "; " + di.GetVersion() + ") Roku")

    ' if obj.GetUrl().Left(4) <> "http"
    '     obj.SetUrl("http://showyou.com/api/" + obj.GetUrl())
    ' endif
End Function

REM ******************************************************
REM Create a new HTTP request. Pass a URL string or an
REM already-existing roUrlTransfer object.
REM ******************************************************
Function NewRequest(url As Object) as Object
    obj = CreateObject("roAssociativeArray")

    if type(url) = "roUrlTransfer" then
        obj.Wrapped = url
    else
        ut = CreateObject("roUrlTransfer")
        ut.SetPort(CreateObject("roMessagePort"))
        ut.SetUrl(url)
        ut.EnableEncodings(true)

        SetUpUrlTransferObject(ut)

        obj.Wrapped = ut
    endif

    obj.Params = {}
    obj.Body = invalid
    obj.ContentType = invalid
    obj.Type = "GET"

    obj.AddParam       = request_add_param
    obj.SetType        = request_set_type
    obj.SetBody        = request_set_body
    obj.GetQueryString = request_get_query_string
    obj.Execute        = request_execute
    obj.Start          = request_start
    obj.GetResponse    = request_get_response

    return obj
End Function

REM ******************************************************
REM Execute all the given requests concurrently. The
REM requests must be given in a hash. The responses will
REM be given back in a new hash with the same keys.
REM Multiple levels are okay; the response hash will
REM mirror the input structure.
REM ******************************************************
Function ExecuteRequests(requests) As Object
    'Start them all off
    start_requests(requests)

    'And grab all the results
    return get_responses(requests)
End Function

Function start_requests(requests)
    for each key in requests
        req = requests[key]

        if type(req.Wrapped) <> "roUrlTransfer"
            ' This isn't a request, it's a nested hash; recurse.
            start_requests(req)
        else
            ' The real nut-meat; start the request!
            req.Start()
        endif
    end for
End Function

Function get_responses(requests) As Object
    results = {}

    for each key in requests
        req = requests[key]

        if type(req.Wrapped) <> "roUrlTransfer"
            ' This isn't a request, it's a nested hash; recurse.
            results[key] = get_responses(req)
        else
            ' The real nut-meat; get the response!
            results[key] = req.GetResponse()
        endif 
    end for

    return results
End Function

REM ******************************************************
REM Add a parameter to the request. The parameter is added
REM to the query string for a GET and as
REM "application/x-www-form-urlencoded" to the body for
REM all other request types.
REM ******************************************************
Function request_add_param(key As String, val As String) As Object
    m.Params[key] = val
    return m
End Function

REM ******************************************************
REM Set the HTTP request type. GET by default.
REM ******************************************************
Function request_set_type(theType As String) As Object
    m.Type = UCase(theType)
    return m
End Function

REM ******************************************************
REM Set the HTTP request body and Content-Type. This
REM forces any parameters to be ignored for POST requests.
REM The body is ignored if this is a HEAD or GET request.
REM ******************************************************
Function request_set_body(body As String, contentType as String) As Object
    m.Body = body
    m.ContentType = contentType
    return m
End Function

REM ******************************************************
REM Get the current parameters URL encoded.
REM ******************************************************
Function request_get_query_string() As String
    qs = ""
    first = true

    for each key in m.Params
        if not first
            qs = qs + "&"
        end if

        qs = qs + m.Wrapped.Escape(key) + "=" + m.Wrapped.Escape(m.Params[key])

        first = false
    end for

    return qs
End Function

REM ******************************************************
REM Start the request asyncronously.
REM ******************************************************
Function request_start()
    if m.Type = "GET"
        if m.Params.Count() > 0
            qs = m.GetQueryString()
            url = m.Wrapped.GetUrl()

            if url.Instr(0, "?") > -1
                m.Wrapped.SetUrl(url + "&" + qs)
            else
                m.Wrapped.SetUrl(url + "?" + qs)
            endif

            m.Params = {}
        endif

        return m.Wrapped.AsyncGetToString()
    elseif m.Type = "HEAD"
        return m.Wrapped.AsyncHead()
    else
        if m.Type <> "POST"
            m.SetRequest(req.Type)
        endif

        body = invalid
        contentType = invalid

        if m.Body <> invalid
            body = m.Body
            contentType = m.ContentType
        elseif m.Params.Count() > 0
            body = m.GetQueryString()
            contentType = "application/x-www-form-urlencoded"
        endif

        if body <> invalid and contentType <> invalid
            m.Wrapped.AddHeader("Content-Type", contentType)
            return m.Wrapped.AsyncPostFromString(body)
        endif
        
        return m.Wrapped.AsyncPostFromString("")
    endif
End Function

REM ******************************************************
REM Wait for the response to come back. Remember to call
REM Start() first!
REM ******************************************************
Function request_get_response()
    event = wait(10000, m.Wrapped.GetPort())
    if type(event) = "roUrlEvent"
        ct = event.GetResponseHeaders()["Content-Type"]
        if ct <> invalid and ct.Instr(0, "application/json") > -1
            res = ParseJson(event.GetString())

            if res = invalid
                return invalid
            endif

            return res
        else
            return event.GetString()
        endif
    elseif event = invalid
        m.Wrapped.AsyncCancel()
        return invalid
    endif
End Function

REM ******************************************************
REM A handy way to execute only the current request.
REM ******************************************************
Function request_execute() As Object
    m.Start()
    return m.GetResponse()
End Function
public with sharing class Utils {
    private static final String API_VERSION = 'v66.0';
    private static final String SESSION_START = 'StartSesh';
    private static final String SESSION_END = 'EndSesh';

    private static String cachedSessionId;

    public static String sendGetRequest(String endpointSuffix) {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String endpoint = baseUrl + '/services/data/' + API_VERSION + endpointSuffix;

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + sessionId());

        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) {
            String message = 'Tooling API request failed (' + res.getStatusCode() + '): ' + res.getBody();
            System.debug(LoggingLevel.ERROR, message);
        }
        return res.getBody();
    }

    private static String sessionId() {
        if (cachedSessionId == null) {
            cachedSessionId = getSessionIdFromVFPage(Page.GetSessionId);
        }
        return cachedSessionId;
    }

    private static String getSessionIdFromVFPage(PageReference visualforcePage) {
        String content = visualforcePage.getContent().toString();
        Integer s = content.indexOf(SESSION_START) + SESSION_START.length();
        Integer e = content.indexOf(SESSION_END);
        return content.substring(s, e);
    }
}
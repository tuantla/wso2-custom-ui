<%--
  ~ Copyright (c) 2014, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
  ~
  ~ WSO2 Inc. licenses this file to you under the Apache License,
  ~ Version 2.0 (the "License"); you may not use this file except
  ~ in compliance with the License.
  ~ You may obtain a copy of the License at
  ~
  ~ http://www.apache.org/licenses/LICENSE-2.0
  ~
  ~ Unless required by applicable law or agreed to in writing,
  ~ software distributed under the License is distributed on an
  ~ "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  ~ KIND, either express or implied.  See the License for the
  ~ specific language governing permissions and limitations
  ~ under the License.
  --%>

<%@ page import="org.apache.cxf.jaxrs.client.JAXRSClientFactory" %>
<%@ page import="org.apache.cxf.jaxrs.provider.json.JSONProvider" %>
<%@ page import="org.apache.cxf.jaxrs.client.WebClient" %>
<%@ page import="org.apache.http.HttpStatus" %>
<%@ page import="org.owasp.encoder.Encode" %>
<%@ page import="org.wso2.carbon.identity.application.authentication.endpoint.util.client.SelfUserRegistrationResource" %>
<%@ page import="org.wso2.carbon.identity.application.authentication.endpoint.util.AuthenticationEndpointUtil" %>
<%@ page import="org.wso2.carbon.identity.application.authentication.endpoint.util.bean.ResendCodeRequestDTO" %>
<%@ page import="org.wso2.carbon.identity.application.authentication.endpoint.util.bean.UserDTO" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="java.net.URLDecoder" %>
<%@ page import="javax.ws.rs.core.Response" %>
<%@ page import="static org.wso2.carbon.identity.core.util.IdentityUtil.isSelfSignUpEPAvailable" %>
<%@ page import="static org.wso2.carbon.identity.core.util.IdentityUtil.isRecoveryEPAvailable" %>
<%@ page import="static org.wso2.carbon.identity.core.util.IdentityUtil.getServerURL" %>
<%@ page import="org.apache.commons.codec.binary.Base64" %>
<%@ page import="org.apache.commons.text.StringEscapeUtils" %>
<%@ page import="java.nio.charset.Charset" %>
<%@ page import="org.wso2.carbon.base.ServerConfiguration" %>
<%@ page import="org.wso2.carbon.identity.application.authentication.endpoint.util.EndpointConfigManager" %>
<%@ page import="org.wso2.carbon.identity.core.URLBuilderException" %>
<%@ page import="org.wso2.carbon.identity.core.ServiceURLBuilder" %>

<jsp:directive.include file="includes/init-loginform-action-url.jsp"/>
<script>
    function goBack() {
        window.history.back();
    }

    // Handle form submission preventing double submission.
    $(document).ready(function(){
        $.fn.preventDoubleSubmission = function() {
            $(this).on('submit',function(e){
                var $form = $(this);
                if ($form.data('submitted') === true) {
                    // Previously submitted - don't submit again.
                    e.preventDefault();
                    console.warn("Prevented a possible double submit event");
                } else {
                    e.preventDefault();

                    var userName = document.getElementById("username");
                    var usernameUserInput = document.getElementById("usernameUserInput");

                    if (usernameUserInput) {
                        userName.value = usernameUserInput.value.trim();
                    }

                    if (userName.value) {
                        $.ajax({
                            type: "GET",
                            url: "<%=loginContextRequestUrl%>",
                            success: function (data) {
                                if (data && data.status == 'redirect' && data.redirectUrl && data.redirectUrl.length > 0) {
                                    window.location.href = data.redirectUrl;
                                } else if ($form.data('submitted') !== true) {
                                    $form.data('submitted', true);
                                    document.getElementById("loginForm").submit();
                                } else {
                                    console.warn("Prevented a possible double submit event.");
                                }
                            },
                            cache: false
                        });
                    }
                }
            });

            return this;
        };
        $('#loginForm').preventDoubleSubmission();
    });

    function showResendReCaptcha() {
        <% if (reCaptchaResendEnabled) { %>
            window.location.href="resend-confirmation-captcha.jsp?<%=AuthenticationEndpointUtil.cleanErrorMessages(Encode.forJava(request.getQueryString()))%>";
        <% } else { %>
            window.location.href="login.do?resend_username=<%=Encode.forHtml(request.getParameter("failedUsername"))%>&<%=AuthenticationEndpointUtil.cleanErrorMessages(Encode.forJava(request.getQueryString()))%>";
        <% } %>
    }
</script>

<%!
    private static final String JAVAX_SERVLET_FORWARD_REQUEST_URI = "javax.servlet.forward.request_uri";
    private static final String JAVAX_SERVLET_FORWARD_QUERY_STRING = "javax.servlet.forward.query_string";
    private static final String UTF_8 = "UTF-8";
    private static final String TENANT_DOMAIN = "tenant-domain";
    private static final String ACCOUNT_RECOVERY_ENDPOINT = "/accountrecoveryendpoint";
    private static final String ACCOUNT_RECOVERY_ENDPOINT_RECOVER = "/recoveraccountrouter.do";
    private static final String ACCOUNT_RECOVERY_ENDPOINT_REGISTER = "/register.do";
%>
<%
    String resendUsername = request.getParameter("resend_username");
    if (StringUtils.isNotBlank(resendUsername)) {

        ResendCodeRequestDTO selfRegistrationRequest = new ResendCodeRequestDTO();
        UserDTO userDTO = AuthenticationEndpointUtil.getUser(resendUsername);
        selfRegistrationRequest.setUser(userDTO);

        String path = config.getServletContext().getInitParameter(Constants.ACCOUNT_RECOVERY_REST_ENDPOINT_URL);
        String proxyContextPath = ServerConfiguration.getInstance().getFirstProperty(IdentityCoreConstants
                .PROXY_CONTEXT_PATH);
        if (proxyContextPath == null) {
            proxyContextPath = "";
        }
        String url;
        if (StringUtils.isNotBlank(EndpointConfigManager.getServerOrigin())) {
            url = EndpointConfigManager.getServerOrigin() + proxyContextPath + path;
        } else {
            url = IdentityUtil.getServerURL(path, true, false);
        }
        url = url.replace(TENANT_DOMAIN, userDTO.getTenantDomain());

        List<JSONProvider> providers = new ArrayList<JSONProvider>();
        JSONProvider jsonProvider = new JSONProvider();
        jsonProvider.setDropRootElement(true);
        jsonProvider.setIgnoreNamespaces(true);
        jsonProvider.setValidateOutput(true);
        jsonProvider.setSupportUnwrapped(true);
        providers.add(jsonProvider);

        String toEncode = EndpointConfigManager.getAppName() + ":" + String
                .valueOf(EndpointConfigManager.getAppPassword());
        byte[] encoding = Base64.encodeBase64(toEncode.getBytes());
        String authHeader = new String(encoding, Charset.defaultCharset());
        String header = "Client " + authHeader;

        SelfUserRegistrationResource selfUserRegistrationResource = JAXRSClientFactory
                .create(url, SelfUserRegistrationResource.class, providers);
        String reCaptchaResponse = request.getParameter("g-recaptcha-response");
        WebClient.client(selfUserRegistrationResource).header("g-recaptcha-response", reCaptchaResponse);
        WebClient.client(selfUserRegistrationResource).header("Authorization", header);
        Response selfRegistrationResponse = selfUserRegistrationResource.regenerateCode(selfRegistrationRequest);
        if (selfRegistrationResponse != null &&  selfRegistrationResponse.getStatus() == HttpStatus.SC_CREATED) {
%>
<div class="ui visible positive message">
    <%=AuthenticationEndpointUtil.i18n(resourceBundle,Constants.ACCOUNT_RESEND_SUCCESS_RESOURCE)%>
</div>
<%
} else {
%>
<div class="ui visible negative message">
    <%=AuthenticationEndpointUtil.i18n(resourceBundle,Constants.ACCOUNT_RESEND_FAIL_RESOURCE)%>
</div>
<%
        }
    }
%>

<% if (Boolean.parseBoolean(loginFailed) && !errorCode.equals(IdentityCoreConstants.USER_ACCOUNT_NOT_CONFIRMED_ERROR_CODE)) { %>
<div class="ui visible negative message" id="error-msg" data-testid="login-page-error-message">
    <%= AuthenticationEndpointUtil.i18n(resourceBundle, errorMessage) %>
</div>
<% } else if ((Boolean.TRUE.toString()).equals(request.getParameter("authz_failure"))){%>
<div class="ui visible negative message" id="error-msg" data-testid="login-page-error-message">
    <%=AuthenticationEndpointUtil.i18n(resourceBundle, "unauthorized.to.login")%>
</div>
<% } else { %>
    <div class="ui visible negative message" style="display: none;" id="error-msg" data-testid="login-page-error-message"></div>
<% } %>

<% if (Boolean.parseBoolean(loginFailed) && errorCode.equals(IdentityCoreConstants.USER_ACCOUNT_NOT_CONFIRMED_ERROR_CODE) && request.getParameter("resend_username") == null) { %>
    <div class="ui visible warning message" id="error-msg" data-testid="login-page-error-message">
        <%= AuthenticationEndpointUtil.i18n(resourceBundle, errorMessage) %>

        <div class="ui divider hidden"></div>

        <%=AuthenticationEndpointUtil.i18n(resourceBundle, "no.confirmation.mail")%>

        <a id="registerLink"
            href="javascript:showResendReCaptcha();"
            data-testid="login-page-resend-confirmation-email-link"
        >
            <%=StringEscapeUtils.escapeHtml4(AuthenticationEndpointUtil.i18n(resourceBundle, "resend.mail"))%>
        </a>
    </div>
    <div class="ui divider hidden"></div>
<% } %>

<form class="ui large form" action="<%=loginFormActionURL%>" method="post" id="loginForm">
    <%
        if (loginFormActionURL.equals(samlssoURL) || loginFormActionURL.equals(oauth2AuthorizeURL)) {
    %>
    <input id="tocommonauth" name="tocommonauth" type="hidden" value="true">
    <%
        }
    %>

    <% if(Boolean.parseBoolean(request.getParameter("passwordReset"))) {
    %>
        <div class="ui visible positive message" data-testid="password-reset-success-message">
            <%=AuthenticationEndpointUtil.i18n(resourceBundle, "Updated.the.password.successfully")%>
        </div>
   <% } %>
    <% if (!isIdentifierFirstLogin(inputType)) { %>
        <div class="col-xs-12 col-sm-12 col-md-12 col-lg-12 form-group">
            <label for="password">Email / Username *</label>
            <input
                        type="text"
                        id="usernameUserInput"
                        value=""
                        name="usernameUserInput"
                        tabindex="1"
                        data-testid="login-page-username-input"
                        required
                        class="form-control">                
                    <input id="username" name="username" type="hidden" value="<%=username%>">

        </div>
        
    <% } else { %>
        <input id="username" name="username" type="hidden" data-testid="login-page-username-input" value="<%=username%>">
    <% } %>
    <div class="col-xs-12 col-sm-12 col-md-12 col-lg-12 form-group">
        <label for="password">Password *</label>
        <input
                    type="password"
                    id="password"
                    name="password"
                    value=""
                    autocomplete="off"
                    tabindex="2"
                    data-testid="login-page-password-input"
                    class="form-control"
                >
    </div>        
    <%
        if (reCaptchaEnabled) {
    %>
        <div class="field">
            <div class="g-recaptcha"
                data-sitekey="<%=Encode.forHtmlContent(request.getParameter("reCaptchaKey"))%>"
                data-testid="login-page-g-recaptcha"
            >
            </div>
        </div>
    <%
        }
    %>

    <%
        String recoveryEPAvailable = application.getInitParameter("EnableRecoveryEndpoint");
        String enableSelfSignUpEndpoint = application.getInitParameter("EnableSelfSignUpEndpoint");
        Boolean isRecoveryEPAvailable = false;
        Boolean isSelfSignUpEPAvailable = false;
        String identityMgtEndpointContext = "";
        String urlEncodedURL = "";
        String urlParameters = "";

        if (StringUtils.isNotBlank(recoveryEPAvailable)) {
            isRecoveryEPAvailable = Boolean.valueOf(recoveryEPAvailable);
        } else {
            isRecoveryEPAvailable = isRecoveryEPAvailable();
        }

        if (StringUtils.isNotBlank(enableSelfSignUpEndpoint)) {
            isSelfSignUpEPAvailable = Boolean.valueOf(enableSelfSignUpEndpoint);
        } else {
            isSelfSignUpEPAvailable = isSelfSignUpEPAvailable();
        }

        if (isRecoveryEPAvailable || isSelfSignUpEPAvailable) {
            String scheme = request.getScheme();
            String serverName = request.getServerName();
            int serverPort = request.getServerPort();
            String uri = (String) request.getAttribute(JAVAX_SERVLET_FORWARD_REQUEST_URI);
            String prmstr = URLDecoder.decode(((String) request.getAttribute(JAVAX_SERVLET_FORWARD_QUERY_STRING)), UTF_8);
            String urlWithoutEncoding = scheme + "://" +serverName + ":" + serverPort + uri + "?" + prmstr;

            urlEncodedURL = URLEncoder.encode(urlWithoutEncoding, UTF_8);
            urlParameters = prmstr;

            identityMgtEndpointContext = application.getInitParameter("IdentityManagementEndpointContextURL");
            if (StringUtils.isBlank(identityMgtEndpointContext)) {
                try {
                    identityMgtEndpointContext = ServiceURLBuilder.create().addPath(ACCOUNT_RECOVERY_ENDPOINT).build()
                            .getAbsolutePublicURL();
                } catch (URLBuilderException e) {
                    request.setAttribute(STATUS, AuthenticationEndpointUtil.i18n(resourceBundle, CONFIGURATION_ERROR));
                    request.setAttribute(STATUS_MSG, AuthenticationEndpointUtil
                            .i18n(resourceBundle, ERROR_WHILE_BUILDING_THE_ACCOUNT_RECOVERY_ENDPOINT_URL));
                    request.getRequestDispatcher("error.do").forward(request, response);
                    return;
                }
            }
        }
    %>
    
    <input type="hidden" name="sessionDataKey" value='<%=Encode.forHtmlAttribute
            (request.getParameter("sessionDataKey"))%>'/>


    <div class="ui two column stackable grid form-group">
        
        <div class="column mobile center aligned tablet right aligned computer right aligned buttons tablet no-margin-right-last-child computer no-margin-right-last-child" style="width: 100%;">
            <button
                type="submit"
                class="primary large button grey-bg"
                tabindex="4"
                role="button"
                data-testid="login-page-continue-login-button"
                style="width: 100%;"
            >
                <%=StringEscapeUtils.escapeHtml4(AuthenticationEndpointUtil.i18n(resourceBundle, "continue"))%>
            </button>
        </div>
    </div>

    <%!
        private String getRecoverAccountUrl(String identityMgtEndpointContext, String urlEncodedURL,
                boolean isUsernameRecovery, String urlParameters) {

            return identityMgtEndpointContext + ACCOUNT_RECOVERY_ENDPOINT_RECOVER + "?" + urlParameters
                    + "&isUsernameRecovery=" + isUsernameRecovery + "&callback=" + Encode
                    .forHtmlAttribute(urlEncodedURL);
        }

        private String getRegistrationUrl(String identityMgtEndpointContext, String urlEncodedURL,
                String urlParameters) {

            return identityMgtEndpointContext + ACCOUNT_RECOVERY_ENDPOINT_REGISTER + "?"
                    + urlParameters + "&callback=" + Encode.forHtmlAttribute(urlEncodedURL);
        }

    %>
</form>

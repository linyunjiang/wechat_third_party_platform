require "wechat_third_party_platform/engine"
require "wechat_third_party_platform/message_encryptor"
require "wechat_third_party_platform/api"
require "wechat_third_party_platform/mini_program_client"

module WechatThirdPartyPlatform
  include HTTParty

  base_uri "https://api.weixin.qq.com"

  LOGGER = ::Logger.new("./log/wechat_third_party_platform.log")

  ACCESS_TOKEN_CACHE_KEY = "wtpp_access_token"
  PRE_AUTH_CODE_CACHE_KEY = "wtpp_pre_auth_code"

  HTTP_ERRORS = [
    EOFError,
    Errno::ECONNRESET,
    Errno::EINVAL,
    Net::HTTPBadResponse,
    Net::HTTPHeaderSyntaxError,
    Net::ProtocolError,
    Timeout::Error
  ]

  TIMEOUT = 5

  mattr_accessor :component_appid, :component_appsecret, :message_token, :message_key, :auth_redirect_url
  mattr_accessor :application_class_name
  @@application_class_name = "Application"

  class<< self
    def get_component_access_token
      access_token = Rails.cache.fetch(ACCESS_TOKEN_CACHE_KEY)

      if access_token.nil?
        component_verify_ticket = Rails.cache.fetch("wtpp_verify_ticket")
        raise "component verify ticket not exist" unless component_verify_ticket
        resp = component_access_token(component_verify_ticket: component_verify_ticket)
        access_token = resp["component_access_token"]
        Rails.cache.write(ACCESS_TOKEN_CACHE_KEY, access_token, expires_in: 115.minutes)
      end
      access_token
    end

    # 令牌
    # https://developers.weixin.qq.com/doc/oplatform/Third-party_Platforms/api/component_access_token.html
    def component_access_token(component_verify_ticket:)
      http_post("/cgi-bin/component/api_component_token", { body: {
        component_appid: component_appid,
        component_appsecret: component_appsecret,
        component_verify_ticket: component_verify_ticket
      } }, false)
    end

    # 预授权码
    # https://developers.weixin.qq.com/doc/oplatform/Third-party_Platforms/api/pre_auth_code.html
    def api_create_preauthcode
      pre_auth_code = fetch_pre_auth_code

      return pre_auth_code if pre_auth_code

      resp = http_post("/cgi-bin/component/api_create_preauthcode", body: {
        component_appid: component_appid
      })

      pre_auth_code = resp["pre_auth_code"]
      cache_pre_auth_code(pre_auth_code)

      pre_auth_code
    end

    def cache_pre_auth_code(pre_auth_code)
      Rails.cache.write(PRE_AUTH_CODE_CACHE_KEY, pre_auth_code, expires_in: 10.minutes)
    end

    def fetch_pre_auth_code
      Rails.cache.fetch(PRE_AUTH_CODE_CACHE_KEY)
    end

    # 使用授权码获取授权信息
    # https://developers.weixin.qq.com/doc/oplatform/Third-party_Platforms/api/authorization_info.html
    def api_query_auth(authorization_code:)
      http_post("/cgi-bin/component/api_query_auth", body: {
        component_appid: component_appid,
        authorization_code: authorization_code
      })
    end

    def refresh_authorizer_access_token(authorizer_appid:, authorizer_refresh_token:)
      http_post("/cgi-bin/component/api_authorizer_token", { body: {
        component_appid: component_appid,
        component_access_token: get_component_access_token,
        authorizer_appid: authorizer_appid,
        authorizer_refresh_token: authorizer_refresh_token
      } })
    end

    # 小程序登录
    # https://developers.weixin.qq.com/doc/oplatform/Third-party_Platforms/Mini_Programs/WeChat_login.html
    def jscode_to_session(appid:, js_code:)
      http_get("/sns/component/jscode2session", body: {
        appid: appid,
        js_code: js_code,
        grant_type: "authorization_code",
        component_appid: component_appid
      })
    end

    # 获取代码草稿列表
    # https://developers.weixin.qq.com/doc/oplatform/Third-party_Platforms/Mini_Programs/code_template/gettemplatedraftlist.html
    def gettemplatedraftlist
      http_get("/wxa/gettemplatedraftlist")
    end

    # 将草稿添加到代码模板库
    # https://developers.weixin.qq.com/doc/oplatform/Third-party_Platforms/Mini_Programs/code_template/addtotemplate.html
    def addtotemplate(draft_id:)
      http_post("/wxa/addtotemplate", body: { draft_id: draft_id })
    end

    # 获取代码模板列表
    # https://developers.weixin.qq.com/doc/oplatform/Third-party_Platforms/Mini_Programs/code_template/gettemplatelist.html
    def gettemplatelist
      http_get("/wxa/gettemplatelist")
    end

    # 删除指定代码模板
    # https://developers.weixin.qq.com/doc/oplatform/Third-party_Platforms/Mini_Programs/code_template/deletetemplate.html
    def deletetemplate(template_id:)
      http_post("/wxa/deletetemplate", body: { template_id: template_id })
    end

    [:get, :post].each do |method|
      define_method "http_#{method}" do |path, options = {}, need_access_token = true|
        body = (options[:body] || {}).select { |_, v| !v.nil? }
        headers = (options[:headers] || {}).reverse_merge({
          "Content-Type" => "application/json",
          "Accept-Encoding" => "*"
        })

        if need_access_token
          path = "#{path}?component_access_token=#{get_component_access_token}"
        end

        uuid = SecureRandom.uuid

        LOGGER.debug("request[#{uuid}]: method: #{method}, url: #{path}, body: #{body}, headers: #{headers}")

        response = begin
                     resp = self.send(method, path, body: JSON.pretty_generate(body), headers: headers, timeout: TIMEOUT).body
                     JSON.parse(resp)
                   rescue JSON::ParserError
                     resp
                   rescue *HTTP_ERRORS
                     { "errmsg" => "连接超时" }
                   end

        LOGGER.debug("response[#{uuid}]: #{response}")

        response
      end
    end
  end
end

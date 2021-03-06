WechatThirdPartyPlatform::Engine.routes.draw do
  post "wechat/authorization_events" => "wechat#authorization_events"
  post '/wechat/:appid/messages', to: 'wechat#messages'
  get '/wechat/auth_callback', to: 'wechat#auth_callback'
  get '/wechat/component_auth', to: 'wechat#component_auth'
end

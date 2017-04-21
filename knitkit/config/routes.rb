Rails.application.routes.draw do
  filter :section_router

  get 'knitkit_mobile' => 'knitkit/mobile#index'
  match 'pages/:section_id' => 'knitkit/website_sections#index', :as => 'page'
  get 'onlinedocumentsections/:section_id' => 'knitkit/online_document_sections#index', :as => 'document'
  get 'onlinedocumentsections/:section_id/show' => 'knitkit/online_document_sections#show'
  get 'blogs/:section_id(.:format)' => 'knitkit/blogs#index', :as => 'blogs'
  get 'blogs/:section_id/:id' => 'knitkit/blogs#show', :as => 'blog_article'
  get 'blogs/:section_id/tag/:tag_id(.:format)' => 'knitkit/blogs#tag', :as => 'blog_tag'

  match '/comments/add' => 'knitkit/comments#add', :as => 'comments'
  match '/unauthorized' => 'knitkit/unauthorized#index', :as => 'knitkit/unauthorized'
  match '/view_current_publication' => 'knitkit/base#view_current_publication'
  match '/online_document_sections(/:action)' => 'knitkit/online_document_sections'

  namespace :api do
    namespace :v1 do

      resources :websites, defaults: { format: 'json' }
      resources :tags, defaults: { format: 'json'}

    end
  end

  get '/captcha/start/:how_many' => 'captcha#start'
  get '/captcha/audio(/:type)' => 'captcha#audio'
  get '/captcha/image/:index' => 'captcha#image'
  put '/captcha/validate' => 'captcha#validate'

end

Knitkit::Engine.routes.draw do
  #Desktop Applications
  #knitkit
  namespace :erp_app do
    namespace :desktop do

      resources :inquiries
      resources :website_nav
      resources :website_nav_item do
        member do
          put :update_security
        end
      end
      resources :website_host
      resources :online_document_sections do
        collection do
          post :copy
          get :existing_documents
        end
        member do
          get :content
        end
      end

      match '/:action' => 'app'
      match '/image_assets/:context/:action' => 'image_assets'
      match '/file_assets/:context/:action' => 'file_assets'
      #article
      match '/articles/:action(/:section_id)' => 'articles'
      #content
      match '/content/:action' => 'content'
      #websit
      match '/site(/:action)' => 'website'
      #section
      match '/section/:action' => 'website_section'
      #theme
      match '/theme/:action' => 'theme'
      #version
      match '/versions/:action' => 'versions'
      #comment
      match '/comments/:action(/:content_id)' => 'comments'
      #position
      match '/position/:action' => 'position'
    end
  end
end

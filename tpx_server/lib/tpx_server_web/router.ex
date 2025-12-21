defmodule TpxServerWeb.Router do
  use TpxServerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug TpxServerWeb.Plugs.Auth
  end

  scope "/", TpxServerWeb do
    pipe_through :api
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
  end

  scope "/", TpxServerWeb do
    pipe_through [:api, :auth]
    get "/users/me", UserController, :me
    patch "/users/me/photo", UserController, :set_photo
    patch "/users/me/background", UserController, :set_background
    patch "/users/me/header_background", UserController, :set_header_background
    patch "/users/me/status", UserController, :set_status
    patch "/users/me/display_name", UserController, :set_display_name
    patch "/users/me/password", UserController, :set_password
    post "/users/block", UserController, :block
    post "/users/unblock", UserController, :unblock
    post "/upload", UploadController, :create

    post "/groups", GroupController, :create
    get "/groups/me", GroupController, :list_my
    post "/groups/:id/join", GroupController, :join
    post "/groups/join_by_name", GroupController, :join_by_name
    post "/groups/:id/add", GroupController, :add
    post "/groups/:id/kick", GroupController, :kick
    post "/groups/:id/ban", GroupController, :ban
    post "/groups/:id/unban", GroupController, :unban
    post "/groups/:id/admins/promote", GroupController, :promote_admin

    get "/groups/:id/messages", MessageController, :list_group
    get "/groups/:id/messages/pinned", MessageController, :list_group_pinned
    get "/groups/:id/messages/search", MessageController, :search_group
    post "/messages/send", MessageController, :send_to_group

    post "/dm", DMController, :create
    get "/dm/me", DMController, :list_mine
    post "/dm/:id/send", DMController, :send
    get "/dm/:id/messages", DMController, :list
    get "/dm/:id/messages/pinned", DMController, :list_pinned
    get "/dm/:id/messages/search", DMController, :search
    patch "/messages/:id", MessageController, :edit
    delete "/messages/:id", MessageController, :delete
    post "/messages/:id/pin", MessageController, :pin
    post "/messages/:id/unpin", MessageController, :unpin
    post "/groups/:id/admins/demote", GroupController, :demote_admin
    post "/groups/:id/leave", GroupController, :leave
    patch "/groups/:id", GroupController, :update_settings
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tpx_server, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: TpxServerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

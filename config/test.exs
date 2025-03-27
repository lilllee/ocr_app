import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ocr_app, OcrAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "/vsy+mJkS/38se5qiWIr+lueDUxcbqaKgRddnrCwioh/Keyn/otCykLGCC2d/Mow",
  server: false

# In test we don't send emails.
config :ocr_app, OcrApp.Mailer,
  adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

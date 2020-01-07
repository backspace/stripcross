defmodule Stripcross.Cache do
  use Nebulex.Cache,
    otp_app: :stripcross,
    adapter: Nebulex.Adapters.Local
end

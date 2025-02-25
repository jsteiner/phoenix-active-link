defmodule PhoenixActiveLink do
  @moduledoc """
  PhoenixActiveLink provides helpers to add active links in views.

  ## Configuration

  Default options can be customized in the configuration:

  ```elixir
  use Mix.Config

  config :phoenix_active_link, :defaults,
    wrap_tag: :li,
    class_active: "enabled",
    class_inactive: "disabled"
  ```

  ## Integrate in Phoenix

  The simplest way to add the helpers to Phoenix is to `import PhoenixActiveLink`
  either in your `web.ex` under views to have it available under every views,
  or under for example `App.LayoutView` to have it available in your layout.
  """

  use Phoenix.HTML

  @opts ~w(active wrap_tag class_active class_inactive active_disable wrap_tag_opts)a

  @doc """
  `active_link/3` is a wrapper around `Phoenix.HTML.Link.link/2`.

  It generates a link and adds an `active` class depending on the
  desired state. It can be customized using the following options.

  ## Options

    * `:active`         - See `active_path?/2` documentation for more information
    * `:wrap_tag`       - Wraps the link in another tag which will also have the same active class.
        This options is useful for usage with `li` in bootstrap for example.
    * `:class_active`   - The class to add when the link is active. Defaults to `"active"`
    * `:class_inactive` - The class to add when the link is not active. Empty by default.
    * `:active_disable` - Uses a `span` element instead of an anchor when not active.

  ## Examples

    ```elixir
    <%= active_link(@conn, "Link text", to: "/my/path") %>
    <%= active_link(@conn, "Link text", to: "/my/path", wrap_tag: :li) %>
    <%= active_link(@conn, "Link text", to: "/my/path", active: :exact) %>
    ```
  """
  def active_link(conn, opts, do: contents) when is_list(opts) do
    active_link(conn, contents, opts)
  end

  def active_link(conn, text, opts) do
    opts = Keyword.merge(default_opts, opts)
    active? = active_path?(conn, opts)
    extra_class = extra_class(active?, opts)
    opts = append_class(opts, extra_class)
    link = make_link(active?, text, opts)
    cond do
      tag = opts[:wrap_tag] -> content_tag(tag, link, wrap_tag_opts(extra_class, opts))
      true                  -> link
    end
  end

  @doc """
  `active_path?/2` is a helper to determine if the element should be in active state or not.

  The `:opts` should contain the `:to` option and the active detection can be customized
  using by passing `:active` one of the following values.

    * `true`       - Will always return `true`
    * `false`      - Will always return `false`
    * `:inclusive` - Will return `true` if the current path starts with the link path.

      For example, `active_path?(conn, to: "/foo")` will return `true` if the path is `"/foo"` or `"/foobar"`.
    * `:exclusive` - Will return `true` if the current path and the link path are the same,
       but will ignore the trailing slashes

       For example, `active_path?(conn, "/foo")` will return `true`
       when the path is `"/foo/"`
    * `:exact`     - Will return `true` if the current path and the link path are exactly the same,
       including trailing slashes.
    * a `%Regex{}` - Will return `true` if the current path matches the regex.

        Beware that `active?(conn, active: ~r/foo/)` will return `true` if the path is `"/bar/foo"`, so
       you must use `active?(conn, active: ~r/^foo/)` if you want to match the begining of the path.
    * a `{controller, action}` list - A list of tuples with a controller module and an action symbol.

        Both can be the `:any` symbol to match any controller or action.

  ## Examples

  ```elixir
  active_path?(conn, to: "/foo")
  active_path?(conn, to: "/foo", active: false)
  active_path?(conn, to: "/foo", active: :exclusive)
  active_path?(conn, to: "/foo", active: ~r(^/foo/[0-9]+))
  active_path?(conn, to: "/foo", active: [{MyController, :index}, {OtherController, :any}])
  ```

  """
  def active_path?(conn, opts) do
    to = Keyword.get(opts, :to, "")
    case Keyword.get(opts, :active, :inclusive) do
      true       -> true
      false      -> false
      :inclusive -> starts_with_path?(conn.request_path, to)
      :exclusive -> String.rstrip(conn.request_path, ?/) == String.rstrip(to, ?/)
      :exact     -> conn.request_path == to
      %Regex{} = regex -> Regex.match?(regex, conn.request_path)
      controller_actions = active when is_list(controller_actions) ->
        controller_actions_active?(conn, active)
      _ -> false
    end
  end

  # NOTE: root path is an exception, otherwise it would be active all the time
  defp starts_with_path?(request_path, "/") when request_path != "/", do: false
  defp starts_with_path?(request_path, to) do
    String.starts_with?(request_path, String.rstrip(to, ?/))
  end

  defp controller_actions_active?(conn, controller_actions) do
    Enum.any? controller_actions, fn {controller, action} ->
      (controller == :any or controller == conn.private.phoenix_controller) and
        (action == :any or action == conn.private.phoenix_action)
    end
  end

  defp wrap_tag_opts(extra_class, opts) do
    Keyword.get(opts, :wrap_tag_opts, [])
    |> append_class(extra_class)
  end

  defp make_link(active?, text, opts) do
    if active? and opts[:active_disable] do
      content_tag(:span, text, span_opts(opts))
    else
      link(text, link_opts(opts))
    end
  end

  defp extra_class(active?, opts) do
    if active? do
      opts[:class_active] || "active"
    else
      opts[:class_inactive] || ""
    end
  end

  defp append_class(opts, class) do
    class =
      opts
      |> Keyword.get(:class, "")
      |> String.split(" ")
      |> List.insert_at(0, class)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(" ")
    Keyword.put(opts, :class, class)
  end

  defp link_opts(opts) do
    Enum.reject(opts, &(elem(&1, 0) in @opts))
  end

  defp span_opts(opts) do
    opts |> link_opts() |> Enum.reject(&(elem(&1, 0) in ~w(to form method)a))
  end

  defp default_opts do
    Application.get_env(:phoenix_active_link, :defaults, [])
  end
end

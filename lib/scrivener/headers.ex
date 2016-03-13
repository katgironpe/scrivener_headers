defmodule Scrivener.Headers do
  @moduledoc """
  Helpers for paginating API responses with [Scrivener](https://github.com/drewolson/scrivener) and HTTP headers. Implements [RFC-5988](https://mnot.github.io/I-D/rfc5988bis/), the proposed standard for Web linking.

  Use `paginate/2` to set the pagination headers:

      def index(conn, params) do
        page = MyApp.Person
               |> where([p], p.age > 30)
               |> order_by([p], desc: p.age)
               |> preload(:friends)
               |> MyApp.Repo.paginate(params)

        conn
        |> Scrivener.Headers.paginate(page)
        |> render("index.json", people: page.entries)
      end
  """

  import Plug.Conn

  alias Plug.Conn.Query

  @rels ~w(first last next prev)

  @doc """
  Add HTTP headers for a `Scrivener.Page`.
  """
  @spec paginate(Plug.Conn.t, Scrivener.Page.t) :: Plug.Conn.t
  def paginate(conn, page) do
    conn
    |> put_link_header(page)
    |> put_resp_header("total", Integer.to_string(page.total_entries))
    |> put_resp_header("per-page", Integer.to_string(page.page_size))
  end

  defp put_link_header(conn, page) do
    link = conn
           |> pages(page)
           |> Enum.join(", ")

    put_resp_header(conn, "link", link)
  end

  defp pages(conn, page) do
    @rels
    |> Enum.map(&(page_link(conn, page, &1)))
    |> Enum.reject(&(&1 == ""))
  end

  defp page_link(conn, %{}, "first"), do: page_link(conn, 1, "first")
  defp page_link(conn, %{total_pages: total}, "last"), do: page_link(conn, total, "last")

  defp page_link(_conn, %{page_number: page, total_pages: total}, "next") when page == total, do: ""
  defp page_link(conn, %{page_number: page}, "next"), do: page_link(conn, page + 1, "next")

  defp page_link(_conn, %{page_number: 1}, "prev"), do: ""
  defp page_link(conn, %{page_number: page}, "prev"), do: page_link(conn, page - 1, "prev")

  defp page_link(conn, page, rel) when is_integer(page) do
    conn
    |> paged_url(page)
    |> page_link(rel)
  end

  defp page_link(url, rel), do: "<#{url}>; rel=\"#{rel}\""

  defp paged_url(conn, page) do
    conn.query_string
    |> Query.decode
    |> Map.put("page", page)
    |> Query.encode
    |> url(conn)
  end

  defp url(query, conn) do
    scheme = Atom.to_string(conn.scheme)
    scheme = "#{scheme}://"

    unless "" == query, do: query = "?#{query}"

    port = if conn.port in [80, 443], do: "", else: ":#{conn.port}"

    [scheme, conn.host, port, conn.request_path, query]
    |> Enum.join("")
  end
end

require "test_helper"

class ChatMessagesHelperTest < ActionView::TestCase
  include ChatMessagesHelper

  # --- Rendering -----------------------------------------------------------

  test "format_markdown renders strong, emphasis, and code" do
    out = format_markdown("**bold** and _em_ and `code`")
    assert_includes out, "<strong>bold</strong>"
    assert_includes out, "<em>em</em>"
    assert_includes out, "<code>code</code>"
  end

  test "format_markdown renders headers and lists" do
    out = format_markdown("# Title\n\n- one\n- two\n")
    assert_includes out, "<h1"
    assert_includes out, "Title"
    assert_includes out, "<ul>"
    assert_includes out, "<li>one</li>"
  end

  test "format_markdown renders GFM tables" do
    out = format_markdown("| a | b |\n|---|---|\n| 1 | 2 |\n")
    assert_includes out, "<table>"
    assert_includes out, "<td>1</td>"
  end

  test "format_markdown returns html_safe output" do
    assert format_markdown("**x**").html_safe?
  end

  # --- Security (defense in depth) ----------------------------------------

  test "format_markdown strips raw script tags" do
    out = format_markdown("hi <script>alert(1)</script>")
    refute_includes out, "<script>"
  end

  test "format_markdown strips javascript: URLs from links" do
    out = format_markdown("[click](javascript:alert(1))")
    refute_match(/href=["']?javascript:/i, out)
  end

  test "format_markdown strips dangerous event-handler attributes" do
    # Raw HTML is omitted by the parser; confirm nothing executable survives
    out = format_markdown("<img src=x onerror=alert(1)>")
    refute_match(/onerror/i, out)
  end

  # --- Edge cases ----------------------------------------------------------

  test "format_markdown returns empty string for blank input" do
    assert_equal "", format_markdown(nil)
    assert_equal "", format_markdown("")
    assert_equal "", format_markdown("   ")
  end
end

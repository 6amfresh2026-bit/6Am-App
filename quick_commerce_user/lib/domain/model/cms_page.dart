/// A CMS-authored page from the backend's landing module. Legal pages carry a
/// title/body; the About page carries the app description and version.
class CmsPage {
  const CmsPage({
    this.title = '',
    this.content = '',
    this.version = '',
    this.email = '',
    this.mobile = '',
  });

  final String title;
  final String content;
  final String version;
  final String email;
  final String mobile;

  bool get isEmpty => title.isEmpty && content.isEmpty;
}

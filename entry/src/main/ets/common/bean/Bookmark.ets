export default class Bookmark {
  id: number | null = null;
  title: string = "";
  url: string = "";

  constructor(title: string, url: string, id?: number) {
    this.title = title;
    this.url = url;
    if (id) {
      this.id = id;
    }
  }
}
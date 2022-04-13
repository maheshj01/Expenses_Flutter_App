class FilterModel {
  bool sortByNewest;
  List<String> labels;
  bool didSortChange;

  FilterModel({this.labels = const [], this.sortByNewest = true,this.didSortChange = true});
}

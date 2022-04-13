class FilterModel {
  bool sortByDate;
  List<String> labels;
  bool didSortChange;
  bool didLabelsChange;

  FilterModel(
      {this.labels = const [],
      this.sortByDate = true,
      this.didSortChange = true,
      this.didLabelsChange = true});
  FilterModel.init()
      : this(
            labels: [],
            sortByDate: true,
            didSortChange: true,
            didLabelsChange: true);
}

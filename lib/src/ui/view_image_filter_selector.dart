part of image_editor;

class ImageFilterController extends ValueNotifier<File> {
  ImageFilterController({File value}) : super(value);
  String filename;

  set file(File file) {
    value = file;
    filename = file != null ? basename(file.path) : null;
    notifyListeners();
  }

  set filter(Filter filter) {
    if (filterChanged != null) {
      filterChanged(filter);
    }
  }

  ValueChanged<Filter> filterChanged;
}

class ImageFilterSelector extends StatelessWidget {
  final Widget loader;
  final BoxFit fit;
  final ImageFilterController controller;
  final Map<String, List<int>> cachedFilters = {};
  final List<Filter> filters;
  final EditorOptions editorOptions;

  ImageFilterSelector({
    Key key,
    @required this.controller,
    List<Filter> filters,
    this.editorOptions = const EditorOptions(),
    this.loader = const Center(child: CircularProgressIndicator()),
    this.fit = BoxFit.cover,
  })  : this.filters = filters ?? presetFiltersList,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<ImageFilterController>(
        builder: (_, __, ___) {
          File file = controller.value;
          if (file == null) return Container();
          cachedFilters.clear();
          return FutureBuilder<img.Image>(
              future: _decodeImageFromFile(file, resize: 200),
              builder: (context, snapshot) {
                return Container(
                  constraints: BoxConstraints(maxHeight: 140),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    itemBuilder: (BuildContext context, int index) {
                      return InkWell(
                        child: Padding(
                          padding:
                              EdgeInsets.all(editorOptions.marginBetween / 2.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              _buildFilterThumbnail(filters[index],
                                  snapshot.data, controller.filename),
                              if (editorOptions.showFilterName)
                                Padding(
                                  padding: const EdgeInsets.only(top: 5.0),
                                  child: SizedBox(
                                    width: editorOptions.thumbnailSize,
                                    child: Center(
                                      child: Text(
                                        filters[index].name,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        onTap: () => controller.filter = filters[index],
                      );
                    },
                  ),
                );
              });
        },
      ),
    );
  }

  Future<img.Image> _decodeImageFromFile(File file, {int resize}) async {
    img.Image image = img.decodeImage(await file.readAsBytes());
    if (resize == null) return image;
    return img.copyResize(image, width: resize);
  }

  _buildFilterThumbnail(Filter filter, img.Image image, String filename) {
    if (image == null) {
      return _buildThumbnailImage(null);
    }
    if (cachedFilters[filter?.name ?? "_"] == null) {
      return FutureBuilder<List<int>>(
        future: compute(applyFilter, <String, dynamic>{
          "filter": filter,
          "image": image,
          "filename": filename,
        }),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.active:
            case ConnectionState.waiting:
              return _buildThumbnailImage(null);
            case ConnectionState.done:
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }
              cachedFilters[filter?.name ?? "_"] = snapshot.data;
              return _buildThumbnailImage(cachedFilters[filter?.name ?? "_"]);
          }
          return null; // unreachable
        },
      );
    } else {
      return _buildThumbnailImage(cachedFilters[filter?.name ?? "_"]);
    }
  }

  Widget _buildThumbnailImage(List<int> bytes) {
    switch (editorOptions.filterThumbnailStyle) {
      case FilterThumbnailStyle.CIRCLE:
        return CircleAvatar(
          radius: editorOptions.thumbnailSize / 2,
          backgroundImage: bytes != null ? MemoryImage(bytes) : null,
          child: bytes == null ? loader : Container(),
          backgroundColor: Colors.white,
        );
      case FilterThumbnailStyle.SQUARE:
        return SizedBox(
          width: editorOptions.thumbnailSize,
          height: editorOptions.thumbnailSize,
          child: bytes != null
              ? Image.memory(
                  bytes,
                  width: editorOptions.thumbnailSize,
                  height: editorOptions.thumbnailSize,
                  fit: BoxFit.cover,
                )
              : loader,
        );
    }
    return null; // unreachable
  }

  Widget buildFilteredImage(AssetItem item) {
    Filter filter = item.filter;
    return FutureBuilder<List<int>>(
      future: _decodeImageFromFile(item.file).then((image) {
        return compute(applyFilter, <String, dynamic>{
          "filter": filter,
          "image": image,
          "filename": basename(item.file.path),
        });
      }),
      builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return loader;
          case ConnectionState.active:
          case ConnectionState.waiting:
            return loader;
          case ConnectionState.done:
            if (snapshot.hasError)
              return Center(child: Text('Error: ${snapshot.error}'));
            cachedFilters[filter?.name ?? "_"] = snapshot.data;
            return Image.memory(
              snapshot.data,
              fit: BoxFit.contain,
            );
        }
        return null; // unreachable
      },
    );
  }
}

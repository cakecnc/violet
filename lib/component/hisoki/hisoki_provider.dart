// This source code is a part of Project Violet.
// Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import 'package:tuple/tuple.dart';
import 'package:violet/component/image_provider.dart';

class HisokiImageProvider extends VioletImageProvider {
  int id;
  List<Tuple3<String, double, double>> infos;

  HisokiImageProvider({this.infos, this.id});

  @override
  Future<void> init() async {}

  @override
  Future<List<String>> getSmallImagesUrl() async {
    throw UnimplementedError();
  }

  @override
  Future<String> getThumbnailUrl() async {
    return 'https://hiso.observer/${(id % 100).toString().padLeft(2, '0')}/$id/cover.webp';
  }

  @override
  Future<Map<String, String>> getHeader(int page) async {
    return {};
  }

  @override
  Future<String> getImageUrl(int page) async {
    return infos[page].item1;
  }

  @override
  int length() {
    return infos.length;
  }

  List<double> _estimatedCache;

  @override
  Future<double> getEstimatedImageHeight(int page, double baseWidth) async {
    return _estimatedCache[page] =
        infos[page].item3 * baseWidth / infos[page].item2;
  }
}
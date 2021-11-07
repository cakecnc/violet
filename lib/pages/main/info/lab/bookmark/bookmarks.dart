// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:animated_widgets/animated_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/main/info/lab/bookmark/bookmarks_article_list.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';

import 'bookmarks_records.dart';

class LabBookmarkPage extends StatefulWidget {
  final String userAppId;

  LabBookmarkPage({this.userAppId});

  @override
  _BookmarkPageState createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<LabBookmarkPage> {
  List<BookmarkArticle> articles;
  List<BookmarkArtist> artists;
  List<BookmarkGroup> groups;
  List<dynamic> records;

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: FutureBuilder(
        // future: Bookmark.getInstance().then((value) => value.getGroup()),
        future: VioletServer.resotreBookmark(widget.userAppId),
        builder: (context, AsyncSnapshot<dynamic> snapshot) {
          if (!snapshot.hasData)
            return Container(
              child: Center(
                child: Text('Loading ...'),
              ),
            );

          if (snapshot.data == null)
            return Container(
              child: Center(
                child: Text('Error Occured!'),
              ),
            );

          articles = (snapshot.data['article'] as List<dynamic>)
              .map((x) => BookmarkArticle(result: x))
              .toList();
          artists = (snapshot.data['artist'] as List<dynamic>)
              .map((x) => BookmarkArtist(result: x))
              .toList();
          groups = (snapshot.data['group'] as List<dynamic>)
              .map((x) => BookmarkGroup(result: x))
              .toList();
          records = snapshot.data['record'] as List<dynamic>;

          ScrollController _scrollController =
              PrimaryScrollController.of(context) ?? ScrollController();

          return ListView.builder(
              padding: EdgeInsets.fromLTRB(4, statusBarHeight + 16, 4, 8),
              physics: BouncingScrollPhysics(),
              controller: _scrollController,
              itemCount: groups.length + 1,
              itemBuilder: (BuildContext ctxt, int index) {
                return _buildItem(index, index == 0 ? null : groups[index - 1]);
              });
        },
      ),
    );
  }

  _buildItem(int index, BookmarkGroup data) {
    index -= 1;

    String name;
    String oname = '';
    String desc;
    String date = '';
    int id;

    if (index == -1) {
      name = Translations.of(context).trans('readrecord');
      desc = Translations.of(context).trans('readrecorddesc');
      id = -1;
    } else {
      name = data.name();
      oname = name;
      desc = data.description();
      date = data.datetime().split(' ')[0];
      id = data.id();
    }

    if (name == 'violet_default') {
      name = Translations.of(context).trans('unclassified');
      desc = Translations.of(context).trans('unclassifieddesc');
    }

    return Container(
      key: Key("lab_bookmark_group_" + id.toString()),
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Settings.themeWhat ? Colors.black26 : Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8)),
          boxShadow: [
            BoxShadow(
              color: Settings.themeWhat
                  ? Colors.black26
                  : Colors.grey.withOpacity(0.1),
              spreadRadius: Settings.themeWhat ? 0 : 5,
              blurRadius: 7,
              offset: Offset(0, 3), // changes position of shadow
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Material(
            color: Settings.themeWhat ? Colors.black38 : Colors.white,
            child: ListTile(
              onTap: () {
                if (!Platform.isIOS) {
                  Navigator.of(context).push(PageRouteBuilder(
                      opaque: false,
                      transitionDuration: Duration(milliseconds: 500),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        var begin = Offset(0.0, 1.0);
                        var end = Offset.zero;
                        var curve = Curves.ease;

                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));

                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                      pageBuilder: (_, __, ___) => id == -1
                          ? LabRecordViewPage(records: records)
                          : LabGroupArticleListPage(
                              articles: articles,
                              artists: artists,
                              groupId: id,
                              name: name,
                            )));
                } else {
                  Navigator.of(context).push(CupertinoPageRoute(
                      builder: (_) => id == -1
                          ? LabRecordViewPage(records: records)
                          : LabGroupArticleListPage(
                              articles: articles,
                              artists: artists,
                              groupId: id,
                              name: name,
                            )));
                }
              },
              onLongPress: () async {
                var yn = await showYesNoDialog(
                    context, '이 북마크 그룹을 끌어올까요?', 'Bookmark Spy');
                if (yn != null && yn) {
                  // 북마크 그룹 생성
                  var groupName =
                      "${widget.userAppId.substring(0, 8)}-${data.name()}";

                  var bookmark = await Bookmark.getInstance();
                  var gid = await bookmark.createGroup(
                      groupName,
                      data.description(),
                      Colors.black,
                      DateTime.parse(data.datetime()));

                  var dir = await getApplicationDocumentsDirectory();
                  var dbraw = await openDatabase('${dir.path}/user.db');
                  await dbraw.transaction((txn) async {
                    final batch = txn.batch();
                    for (var article in articles) {
                      if (article.group() != data.id()) continue;
                      var ref = article;
                      batch.insert(
                          'BookmarkArticle',
                          {
                            'Article': ref.article(),
                            'DateTime': ref.datetime(),
                            'GroupId': gid,
                          },
                          conflictAlgorithm: ConflictAlgorithm.fail);
                    }
                    await batch.commit();
                  });
                  await dbraw.transaction((txn) async {
                    final batch = txn.batch();
                    for (var artist in artists) {
                      if (artist.group() != data.id()) continue;
                      var ref = artist;
                      batch.insert(
                          'BookmarkArtist',
                          {
                            'Artist': ref.artist(),
                            'IsGroup': ref.type(),
                            'DateTime': ref.datetime(),
                            'GroupId': gid,
                          },
                          conflictAlgorithm: ConflictAlgorithm.fail);
                    }
                    await batch.commit();
                  });
                  await dbraw.close();

                  await showOkDialog(
                      context, '북마크 그룹을 성공적으로 끌어왔습니다!', 'Bookmark Spy');
                }
              },
              title: Text(name, style: TextStyle(fontSize: 16.0)),
              subtitle: Text(desc),
              trailing: Text(date),
            ),
          ),
        ),
      ),
    );
  }
}
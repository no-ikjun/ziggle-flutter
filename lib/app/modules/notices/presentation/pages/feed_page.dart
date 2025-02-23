import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ziggle/app/di/locator.dart';
import 'package:ziggle/app/modules/auth/presentation/bloc/auth_bloc.dart';
import 'package:ziggle/app/router/routes.dart';
import 'package:ziggle/app/values/palette.dart';
import 'package:ziggle/gen/assets.gen.dart';
import 'package:ziggle/gen/strings.g.dart';

import '../../domain/entities/notice_entity.dart';
import '../../domain/enums/notice_reaction.dart';
import '../../domain/enums/notice_type.dart';
import '../bloc/notice_list_bloc.dart';
import '../cubit/share_cubit.dart';
import '../widgets/infinite_scroll.dart';
import '../widgets/notice_card.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              sl<NoticeListBloc>()..add(const NoticeListEvent.load()),
        ),
        BlocProvider(create: (_) => sl<ShareCubit>()),
      ],
      child: const _Layout(),
    );
  }
}

class _Layout extends StatelessWidget {
  const _Layout();

  @override
  Widget build(BuildContext context) {
    final mediaQueryPadding = MediaQuery.paddingOf(context);
    final toolbarHeight = Theme.of(context).appBarTheme.toolbarHeight!;
    final bottomHeight = toolbarHeight + 8;

    return Scaffold(
      backgroundColor: Palette.background200,
      body: SafeArea(
        left: false,
        right: false,
        bottom: false,
        child: RefreshIndicator(
          edgeOffset: mediaQueryPadding.top + toolbarHeight,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            final bloc = context.read<NoticeListBloc>()
              ..add(const NoticeListEvent.refresh());
            await bloc.stream.firstWhere((state) => state.loaded);
          },
          child: InfiniteScroll(
            onLoadMore: () => context.read<NoticeListBloc>()
              ..add(const NoticeListEvent.loadMore()),
            slivers: [
              SliverAppBar(
                backgroundColor: Palette.background200,
                toolbarHeight: toolbarHeight,
                floating: true,
                leadingWidth: 100,
                leading: Row(
                  children: [
                    const SizedBox(width: 12),
                    Assets.logo.light.svg(width: 75),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Assets.icons.search.svg(),
                    onPressed: () => const SearchRoute().push(context),
                  ),
                  IconButton(
                    icon: Assets.icons.editPencil.svg(),
                    onPressed: () => const WriteRoute().push(context),
                  ),
                  IconButton(
                    icon: Assets.icons.user.svg(),
                    onPressed: () => const MyPageRoute().push(context),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(bottomHeight),
                  child: _buildNoticeTypeChips(),
                ),
              ),
              SliverSafeArea(
                top: false,
                sliver: BlocBuilder<NoticeListBloc, NoticeListState>(
                  builder: (context, state) => state.list.isEmpty
                      ? SliverPadding(
                          padding: const EdgeInsets.only(top: 8),
                          sliver: SliverToBoxAdapter(
                            child: Center(
                              child: state.loaded
                                  ? Text(t.notice.noNotice)
                                  : const CircularProgressIndicator(),
                            ),
                          ),
                        )
                      : _buildList(state),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverList _buildList(NoticeListState state) {
    return SliverList.builder(
      itemCount: state.list.length + (state.loaded ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == state.list.length) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        final notice = state.list[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7.5),
          child: NoticeCard(
            notice: notice,
            onTapDetail: () => NoticeRoute.fromEntity(notice).push(context),
            onTapLike: () {
              HapticFeedback.lightImpact();
              final userId = AuthBloc.userOrNull(context)?.uuid;
              if (userId == null) {
                const LoginRoute().push(context);
                return;
              }
              const like = NoticeReaction.like;
              final liked = notice.reacted(like);
              context.read<NoticeListBloc>().add(liked
                  ? NoticeListEvent.removeReaction(notice.id, like.emoji)
                  : NoticeListEvent.addReaction(notice.id, like.emoji));
            },
            onTapShare: () => context.read<ShareCubit>().share(notice),
            onTapReminder: () {
              if (AuthBloc.userOrNull(context) == null) {
                const LoginRoute().push(context);
                return;
              }
              HapticFeedback.lightImpact();
              context.read<NoticeListBloc>().add(
                    notice.isReminded
                        ? NoticeListEvent.removeReminder(notice.id)
                        : NoticeListEvent.addReminder(notice.id),
                  );
            },
          ),
        );
      },
    );
  }

  Widget _buildNoticeTypeChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: BlocBuilder<NoticeListBloc, NoticeListState>(
          builder: (context, state) => Wrap(
            spacing: 8,
            children: NoticeType.sections
                .map(
                  (e) => ActionChip.elevated(
                    labelPadding: const EdgeInsets.only(right: 8),
                    avatar: e.icon.svg(
                      width: 16,
                      colorFilter: e == state.type
                          ? const ColorFilter.mode(
                              Palette.background100, BlendMode.srcIn)
                          : null,
                    ),
                    label: Row(
                      children: [
                        Text(e.label),
                        ClipRect(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.centerLeft,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: SizedBox(
                                width: e != state.type ? 0 : null,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                    color: e == state.type
                                        ? Palette.background100
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (e == state.type) {
                        SectionRoute(type: e).push(context);
                        return;
                      }
                      context
                          .read<NoticeListBloc>()
                          .add(NoticeListEvent.load(type: e));
                    },
                    labelStyle: TextStyle(
                      color: e == state.type ? Palette.background100 : null,
                      fontWeight: e == state.type ? FontWeight.w700 : null,
                    ),
                    backgroundColor:
                        e == state.type ? Palette.primary100 : null,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

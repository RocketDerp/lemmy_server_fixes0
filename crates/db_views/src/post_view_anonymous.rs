use crate::{structs::{PostAnonymousView}, post_view::PostQuery};
use diesel::{
  debug_query,
  dsl::{now, IntervalDsl},
  pg::Pg,
  result::Error,
  sql_function,
  sql_types,
  BoolExpressionMethods,
  ExpressionMethods,
  JoinOnDsl,
  NullableExpressionMethods,
  PgTextExpressionMethods,
  QueryDsl,
};
use diesel_async::RunQueryDsl;
use lemmy_db_schema::{
  aggregates::structs::PostAggregates,
  newtypes::{PersonId, PostId},
  schema::{
    community,
    person,
    post,
    post_aggregates,
  },
  source::{
    community::Community,
    person::Person,
    post::Post,
  },
  traits::JoinView,
  utils::{fuzzy_search, limit_and_offset, DbConn, DbPool, ListFn, Queries, ReadFn},
  SortType,
};

/*
I propose a Extras object that holds all those fields
  about creator banned from community, etc.
 */
type PostAnonymousViewTuple = (
  Post,
  Person,
  Community,
  PostAggregates,
);

fn queries<'a>() -> Queries<
  impl ReadFn<'a, PostAnonymousView, (PostId, Option<PersonId>, bool)>,
  impl ListFn<'a, PostAnonymousView, PostQuery<'a>>,
> {
  let all_joins = |query: post_aggregates::BoxedQuery<'a, Pg>, my_person_id: Option<PersonId>| {

    query
      .inner_join(person::table)
      .inner_join(community::table)
      .inner_join(post::table)
  };

  let selection = (
    post::all_columns,
    person::all_columns,
    community::all_columns,
    post_aggregates::all_columns,
  );

  // the read function is not used, only the list, so this is damaged.
  let read =
    move |mut conn: DbConn<'a>,
          (post_id, my_person_id, is_mod_or_admin): (PostId, Option<PersonId>, bool)| async move {
      let mut query = all_joins(
        post_aggregates::table
          .filter(post_aggregates::post_id.eq(post_id))
          .into_boxed(),
        my_person_id,
      )
      .select(selection);

      query.first::<PostAnonymousViewTuple>(&mut conn).await
    };

  let list = move |mut conn: DbConn<'a>, options: PostQuery<'a>| async move {
    let person_id = options.local_user.map(|l| l.person.id);

    let mut query = all_joins(post_aggregates::table.into_boxed(), person_id)
      .select(selection);

    // This logic is confusing to me. creator of what? Each individual post?
    //   I just don't see how the query is being set up that way, will study SQL
    //   generated by this.
    let is_creator = options.creator_id == options.local_user.map(|l| l.person.id);
    // only show deleted posts to creator
    if is_creator {
      query = query
        .filter(community::deleted.eq(false))
        .filter(post::deleted.eq(false));
    }

    query = query
    .filter(community::removed.eq(false))
    .filter(post::removed.eq(false));

    if options.community_id.is_none() {
      query = query.then_order_by(post_aggregates::featured_local.desc());
    } else if let Some(community_id) = options.community_id {
    // targeting a specific community
    query = query
        .filter(post_aggregates::community_id.eq(community_id))
        .then_order_by(post_aggregates::featured_community.desc());
    }

    if let Some(creator_id) = options.creator_id {
      query = query.filter(post_aggregates::creator_id.eq(creator_id));
    }

    if let Some(url_search) = options.url_search {
      query = query.filter(post::url.eq(url_search));
    }

    if let Some(search_term) = options.search_term {
      let searcher = fuzzy_search(&search_term);
      query = query.filter(
        post::name
          .ilike(searcher.clone())
          .or(post::body.ilike(searcher)),
      );
    }

    // defaults to not show NSFW
    query = query
    .filter(post::nsfw.eq(false))
    .filter(community::nsfw.eq(false));

    query = match options.sort.unwrap_or(SortType::Hot) {
      SortType::Active => query
        .then_order_by(post_aggregates::hot_rank_active.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::Hot => query
        .then_order_by(post_aggregates::hot_rank.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::Controversial => query.then_order_by(post_aggregates::controversy_rank.desc()),
      SortType::New => query.then_order_by(post_aggregates::published.desc()),
      SortType::Old => query.then_order_by(post_aggregates::published.asc()),
      SortType::NewComments => query.then_order_by(post_aggregates::newest_comment_time.desc()),
      SortType::MostComments => query
        .then_order_by(post_aggregates::comments.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::TopAll => query
        .then_order_by(post_aggregates::score.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::TopYear => query
        .filter(post_aggregates::published.gt(now - 1.years()))
        .then_order_by(post_aggregates::score.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::TopMonth => query
        .filter(post_aggregates::published.gt(now - 1.months()))
        .then_order_by(post_aggregates::score.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::TopWeek => query
        .filter(post_aggregates::published.gt(now - 1.weeks()))
        .then_order_by(post_aggregates::score.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::TopDay => query
        .filter(post_aggregates::published.gt(now - 1.days()))
        .then_order_by(post_aggregates::score.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::TopHour => query
        .filter(post_aggregates::published.gt(now - 1.hours()))
        .then_order_by(post_aggregates::score.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::TopSixHour => query
        .filter(post_aggregates::published.gt(now - 6.hours()))
        .then_order_by(post_aggregates::score.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::TopTwelveHour => query
        .filter(post_aggregates::published.gt(now - 12.hours()))
        .then_order_by(post_aggregates::score.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::TopThreeMonths => query
        .filter(post_aggregates::published.gt(now - 3.months()))
        .then_order_by(post_aggregates::score.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::TopSixMonths => query
        .filter(post_aggregates::published.gt(now - 6.months()))
        .then_order_by(post_aggregates::score.desc())
        .then_order_by(post_aggregates::published.desc()),
      SortType::TopNineMonths => query
        .filter(post_aggregates::published.gt(now - 9.months()))
        .then_order_by(post_aggregates::score.desc())
        .then_order_by(post_aggregates::published.desc()),
    };

    let (limit, offset) = limit_and_offset(options.page, options.limit)?;

    query = query.limit(limit).offset(offset);

    tracing::warn!("Post View Anon Query: {:?}", debug_query::<Pg, _>(&query));

    query.load::<PostAnonymousViewTuple>(&mut conn).await
  };

  Queries::new(read, list)
}


impl<'a> PostQuery<'a> {
  pub async fn list_anonymous(self, pool: &mut DbPool<'_>) -> Result<Vec<PostAnonymousView>, Error> {
    queries().list(pool, self).await
    }
}

impl JoinView for PostAnonymousView {
  type JoinTuple = PostAnonymousViewTuple;
  fn from_tuple(a: Self::JoinTuple) -> Self {
    Self {
      post: a.0,
      creator: a.1,
      community: a.2,
      counts: a.3,
    }
  }
}

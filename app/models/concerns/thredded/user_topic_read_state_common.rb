# frozen_string_literal: true

module Thredded
  module UserTopicReadStateCommon
    extend ActiveSupport::Concern
    included do
      extend ClassMethods
      validates :user_id, uniqueness: { scope: :postable_id }
      attribute :first_unread_post_page, ActiveRecord::Type::Integer.new
    end

    # @return [Boolean]
    def read?
      postable.last_post_at <= read_at
    end

    # @param post [Post or PrivatePost]
    # @return [Boolean]
    def post_read?(post)
      post.created_at <= read_at
    end

    module ClassMethods
      # @param user_id [Integer]
      # @param topic_id [Integer]
      # @param post [Thredded::PostCommon]
      # @param post_page [Integer]
      def touch!(user_id, topic_id, post, post_page)
        # TODO: Switch to upsert once Travis supports PostgreSQL 9.5.
        # Travis issue: https://github.com/travis-ci/travis-ci/issues/4264
        # Upsert gem: https://github.com/seamusabshere/upsert
        state = find_or_initialize_by(user_id: user_id, postable_id: topic_id)
        fail ArgumentError, "expected post_page >= 1, given #{post_page.inspect}" if post_page < 1
        return unless !state.read_at? || state.read_at < post.created_at
        state.update!(read_at: post.created_at, page: post_page)
      end

      def read_on_first_post!(user, topic)
        create!(user: user, postable: topic, read_at: Time.zone.now, page: 1)
      end

      # Adds a `first_unread_post_page` column onto the scope.
      def include_first_unread_page(
        posts_per_page: topic_class.default_per_page, posts_scope: post_class.all
      )
        states = arel_table
        read = if posts_scope == post_class.unscoped
                 post_class.arel_table
               else
                 posts_subquery = Thredded::ArelCompat.relation_to_arel(posts_scope)
                 Arel::Nodes::TableAlias.new(posts_subquery, 'read_posts')
               end
        topics = topic_class.arel_table
        first_unread =
          states
            .project(
              states[:id],
              Arel::Nodes::Addition.new(Thredded::ArelCompat.integer_division(self, read[:id].count, posts_per_page), 1)
                .as('first_unread_post_page')
            )
            .join(read)
            .on(read[:postable_id].eq(states[:postable_id]).and(read[:created_at].lteq(states[:read_at])))
            .group(states[:id])
            .join(topics)
            .on(states[:postable_id].eq(topics[:id]).and(topics[:last_post_at].gt(states[:read_at])))
            .as('id_and_first_unread')

        # We use a subquery because selected fields must appear in the GROUP BY or be used in an aggregate function.
        select(states[Arel.star], first_unread[:first_unread_post_page])
          .joins(states.outer_join(first_unread).on(states[:id].eq(first_unread[:id])).join_sources)
      end

      def topic_class
        reflect_on_association(:postable).klass
      end

      delegate :post_class, to: :topic_class
    end
  end
end

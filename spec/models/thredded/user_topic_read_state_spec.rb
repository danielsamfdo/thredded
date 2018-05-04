# frozen_string_literal: true

require 'spec_helper'

module Thredded
  describe UserTopicReadState, '#post_read?(post)' do
    let(:read_state) { create(:user_topic_read_state, read_at: 1.day.ago) }

    it 'is true when post.created_at > read_at' do
      post = create(:post, created_at: 2.days.ago)
      expect(read_state.post_read?(post)).to be_truthy
    end

    it 'is true when post.created_at = read_at' do
      post = create(:post, created_at: read_state.read_at)
      expect(read_state.post_read?(post)).to be_truthy
    end

    it 'is false when post.created_at < read_at' do
      post = create(:post, created_at: 1.minute.ago)
      expect(read_state.post_read?(post)).to be_falsey
    end
  end

  describe UserTopicReadState, '.include_first_unread' do
    let(:topic) { create(:topic, with_posts: 5) }
    let(:posts) { topic.posts.to_a.sort_by(&:created_at) }

    it 'returns the first unread post page' do
      create(:user_topic_read_state, postable: topic, read_at: posts[1].created_at)
      expect(UserTopicReadState.include_first_unread_page(posts_per_page: 3).to_a)
        .to(contain_exactly(have_attributes(first_unread_post_page: 1)))
      expect(UserTopicReadState.include_first_unread_page(posts_per_page: 2).to_a)
        .to(contain_exactly(have_attributes(first_unread_post_page: 2)))
      expect(UserTopicReadState.include_first_unread_page(posts_per_page: 1).to_a)
        .to(contain_exactly(have_attributes(first_unread_post_page: 3)))
    end

    it 'returns nil post ID if there are no unread posts' do
      create(:user_topic_read_state, postable: topic, read_at: posts[-1].created_at)
      expect(UserTopicReadState.include_first_unread_page(posts_per_page: 3).to_a)
        .to(contain_exactly(have_attributes(first_unread_post_page: nil)))
    end

    it 'respects the given posts_scope' do
      create(:user_topic_read_state, postable: topic, read_at: posts[0].created_at)
      posts_scope = Thredded::Post.where.not(id: posts[1].id)
      expect(UserTopicReadState.include_first_unread_page(posts_per_page: 1, posts_scope: posts_scope).to_a)
        .to(contain_exactly(have_attributes(first_unread_post_page: 2)))
    end
  end

  describe NullUserTopicReadState, '#post_read?(post)' do
    it 'is false' do
      post = create(:post)
      null_user_topic_read_state = NullUserTopicReadState.new
      expect(null_user_topic_read_state.post_read?(post)).to be_falsey
    end
  end
end

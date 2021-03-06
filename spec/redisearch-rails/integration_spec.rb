require 'spec_helper'

describe RediSearch do
  before do
    rebuild_model 'User' do
      redisearch schema: {
        first_name: :text
      }
    end

    rebuild_model 'Company' do
      redisearch schema: {
        name: :text
      }
    end
  end

  context "When ActiveRecord class has redisearch called on class" do
    context "with defaults" do
      it "defines reindex and rediseach methods" do
        expect(User.respond_to?(:reindex)).to be true
        expect(User.respond_to?(:redisearch)).to be true
      end

      it "defines redisearch_import default scope" do
        expect(User.respond_to?(:redisearch_import)).to be true
        expect(User.redisearch_import.to_sql).to eq User.all.to_sql
      end

      it "the index name its the same of the model plural name" do
        expect(User.redisearch_index.name).to eq User.model_name.plural
      end

      it "the Redisearch models have all the models name with redisearch" do
        expect(RediSearch.models).to include(User, Company)
      end
    end

    context "overwrite scope" do
      before do
        rebuild_model 'User' do
          redisearch schema: {
            first_name: :text
          }

          scope :redisearch_import, -> { where(first_name: 'Jon') }
        end
      end

      it "change redisearch_import scope" do
        expect(User.redisearch_import.to_sql).to eq User.where(first_name: 'Jon').to_sql
      end
    end

    context "using prefix" do
      before do
        rebuild_model 'User' do
          redisearch schema: {
            first_name: :text
          }, prefix: 'the'
        end
      end

      it "the index name have the prefix" do
        expect(User.redisearch_index.name).to eq "the_#{User.model_name.plural}"
      end
    end
  end

  context "Instance Object with redisearch" do
    before do
      User.reindex(recreate: true)
    end
    let(:user) { User.create(first_name: 'name') }

    it "defines redisearch_document" do
      expect(user.respond_to?(:redisearch_document)).to be true
    end

    it "document has the id of the model prefixed by index name" do
      expect(user.redisearch_document.doc_id).to eq "#{User.redisearch_index.name}_#{user.id}"
    end

    it "index with default callbacks on create" do
      expect(user.class.redisearch_count).to eq 1
    end

    context "with callbacks async" do
      before do
        rebuild_model 'User' do
          redisearch schema: {
            first_name: :text
          }, callbacks: :async
        end
        User.reindex(recreate: true)
      end

      it "enqueue the job" do
        user
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq 1
      end

    end
  end
end

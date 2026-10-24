# frozen_string_literal: true

RSpec.describe WoodsMap::UnitCoChanges do
  def co_changes(paths, own)
    WoodsMap::Repository.open(FIXTURE_INDEX) do |repository|
      yield described_class.new(repository, repository.git_commits, paths, own: own)
    end
  end

  it 'folds co-changed files onto their units and drops single-commit noise once enough units repeat' do
    co_changes(['app/jobs/application_job.rb'], %w[ApplicationJob job]) do |co|
      top = co.top(8)
      expect(top.map { |c| [c.identifier, c.commits] }).to eq([['MailingListMailer', 2], ['Micropost', 2],
                                                               ['mailing_list_mailer/new_post.html.erb', 2]])
    end
  end

  it 'keeps single shared commits when little repeats' do
    co_changes(['app/models/user.rb'], %w[User model]) do |co|
      expect(co.top(3).map(&:commits).uniq).to eq([1])
    end
  end
end

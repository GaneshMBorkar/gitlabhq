require 'rails_helper'

feature 'issue move to another project' do
  let(:user) { create(:user) }
  let(:old_project) { create(:project) }
  let(:text) { 'Some issue description' }

  let(:issue) do
    create(:issue, description: text, project: old_project, author: user)
  end

  background { login_as(user) }

  context 'user does not have permission to move issue' do
    background do
      old_project.team << [user, :guest]

      edit_issue(issue)
    end

    scenario 'moving issue to another project not allowed' do
      expect(page).to have_no_select('move_to_project_id')
    end
  end

  context 'user has permission to move issue' do
    let!(:mr) { create(:merge_request, source_project: old_project) }
    let(:new_project) { create(:project) }
    let(:text) { 'Text with !1' }
    let(:cross_reference) { old_project.to_reference }

    background do
      old_project.team << [user, :reporter]
      new_project.team << [user, :reporter]

      edit_issue(issue)
    end

    scenario 'moving issue to another project', js: true do
      find('#s2id_move_to_project_id').click
      find('.select2-drop li', text: new_project.name_with_namespace).click
      click_button('Save changes')

      expect(current_url).to include project_path(new_project)

      page.within('.issue') do
        expect(page).to have_content("Text with #{cross_reference}!1")
        expect(page).to have_content("Moved from #{cross_reference}#1")
        expect(page).to have_content(issue.title)
      end
    end

    context 'projects user does not have permission to move issue to exist' do
      let!(:private_project) { create(:project, :private) }
      let(:another_project) { create(:project) }
      background { another_project.team << [user, :guest] }

      scenario 'browsing projects in projects select' do
        options = [ '', 'No project', new_project.name_with_namespace ]
        expect(page).to have_select('move_to_project_id', options: options)
      end
    end
  end

  def edit_issue(issue)
    visit issue_path(issue)
    page.within('.issuable-header') { click_link 'Edit' }
  end

  def issue_path(issue)
    namespace_project_issue_path(issue.project.namespace, issue.project, issue)
  end

  def project_path(project)
    namespace_project_path(new_project.namespace, new_project)
  end
end

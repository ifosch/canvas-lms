#
# Copyright (C) 2014 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require File.expand_path(File.dirname(__FILE__) + '../../../spec_helper.rb')

module Importers
  describe Importers::AttachmentImporter do

    describe '#process_migration', no_retry: true do
      let(:course) { ::Course.new }
      let(:course_id) { 1 }
      let(:migration) { ContentMigration.new(context: course) }
      let(:migration_id) { 123 }
      let(:attachment_id) { 456 }
      let(:attachment) { stub(:context= => true, :migration_id= => true, :save_without_broadcasting! => true) }

      before :each do
        course.imported_migration_items = []
        course.stubs(:id).returns(course_id)
        migration.stubs(:import_object?).with('attachments', migration_id).returns(true)
      end

      it 'imports an attachment' do
        data = {
            'file_map' => {
                'a' => {
                    id: attachment_id,
                    migration_id: migration_id
                }
            }
        }

        ::Attachment.expects(:find_by_context_type_and_context_id_and_id).with("Course", course_id, attachment_id).returns(attachment)
        migration.expects(:import_object?).with('attachments', migration_id).returns(true)
        attachment.expects(:context=).with(course)
        attachment.expects(:migration_id=).with(migration_id)
        attachment.expects(:locked=).never
        attachment.expects(:file_state=).never
        attachment.expects(:display_name=).never
        attachment.expects(:save_without_broadcasting!)

        Importers::AttachmentImporter.process_migration(data, migration)

        course.imported_migration_items.should == [attachment]
      end

      it "imports attachments when the migration id is in the files_to_import hash" do
        data = {
            'file_map' => {
                'a' => {
                    id: attachment_id,
                    migration_id: migration_id,
                    files_to_import: {
                        migration_id => true
                    }
                }
            }
        }

        ::Attachment.expects(:find_by_context_type_and_context_id_and_id).with("Course", course_id, attachment_id).returns(attachment)
        migration.expects(:import_object?).with('attachments', migration_id).returns(true)
        attachment.expects(:save_without_broadcasting!)

        Importers::AttachmentImporter.process_migration(data, migration)
      end

      it "finds attachments by migration id" do
        data = {
            'file_map' => {
                'a' => {
                    id: attachment_id,
                    migration_id: migration_id,
                }
            }
        }

        ::Attachment.stubs(:find_by_context_type_and_context_id_and_id).with("Course", course_id, attachment_id).returns(nil)
        ::Attachment.stubs(:find_by_context_type_and_context_id_and_migration_id).with("Course", course_id, migration_id).returns(attachment)
        migration.expects(:import_object?).with('attachments', migration_id).returns(true)
        attachment.expects(:save_without_broadcasting!)

        Importers::AttachmentImporter.process_migration(data, migration)
      end

      it "finds attachment from the path" do
        data = {
            'file_map' => {
                'a' => {
                    id: attachment_id,
                    migration_id: migration_id,
                    path_name: "path/to/file"
                }
            }
        }

        ::Attachment.stubs(:find_by_context_type_and_context_id_and_id).with("Course", course_id, attachment_id).returns(nil)
        ::Attachment.stubs(:find_by_context_type_and_context_id_and_migration_id).with("Course", course_id, migration_id).returns(nil)
        ::Attachment.stubs(:find_from_path).with("path/to/file", course).returns(attachment)
        migration.expects(:import_object?).with('attachments', migration_id).returns(true)
        attachment.expects(:save_without_broadcasting!)

        Importers::AttachmentImporter.process_migration(data, migration)
      end

      it "uses files if attachments are not found on the migration" do
        data = {
            'file_map' => {
                'a' => {
                    id: attachment_id,
                    migration_id: migration_id
                }
            }
        }

        ::Attachment.expects(:find_by_context_type_and_context_id_and_id).with("Course", course_id, attachment_id).returns(attachment)
        migration.stubs(:import_object?).with('attachments', migration_id).returns(false)
        migration.stubs(:import_object?).with('files', migration_id).returns(true)

        attachment.expects(:save_without_broadcasting!)

        Importers::AttachmentImporter.process_migration(data, migration)
      end

      it "does not add to the imported_migration_items if imported_migration_items is nil" do
        data = {
            'file_map' => {
                'a' => {
                    id: attachment_id,
                    migration_id: migration_id
                }
            }
        }

        course.imported_migration_items = nil
        ::Attachment.expects(:find_by_context_type_and_context_id_and_id).with("Course", course_id, attachment_id).returns(attachment)
        migration.expects(:import_object?).with('attachments', migration_id).returns(true)
        attachment.expects(:save_without_broadcasting!)

        Importers::AttachmentImporter.process_migration(data, migration)

        course.imported_migration_items.should == nil
      end

      it "does not import files that are not part of the migration" do
        data = {
            'file_map' => {
                'a' => {
                    id: attachment_id,
                    migration_id: migration_id,
                    files_to_import: {}
                }
            }
        }

        ::Attachment.expects(:find_by_context_type_and_context_id_and_id).never

        Importers::AttachmentImporter.process_migration(data, migration)
      end

      it "does not import files if there is a file_to_import key" do
        data = {
            'file_map' => {
                'a' => {
                    id: attachment_id,
                    migration_id: migration_id,
                    files_to_import: {
                    }
                }
            }
        }

        ::Attachment.expects(:find_by_context_type_and_context_id_and_id).never

        Importers::AttachmentImporter.process_migration(data, migration)
      end

      it 'sets locked, file_state, and display_name when present' do
        data = {
            'file_map' => {
                'a' => {
                    id: attachment_id,
                    migration_id: migration_id,
                    locked: true,
                    hidden: true,
                    display_name: "display name"
                }
            }
        }

        ::Attachment.stubs(:find_by_context_type_and_context_id_and_id).with("Course", course_id, attachment_id).returns(attachment)
        attachment.expects(:locked=).with(true)
        attachment.expects(:file_state=).with('hidden')
        attachment.expects(:display_name=).with('display name')

        Importers::AttachmentImporter.process_migration(data, migration)
      end

      it "locks folders" do
        data = {
            locked_folders: [
                "path1/foo",
                "path2/bar"
            ]
        }

        active_folders_association = stub()
        course.expects(:active_folders).returns(active_folders_association).twice
        folder = stub()
        active_folders_association.stubs(:find_by_full_name).with("course files/path1/foo").returns(folder)
        active_folders_association.stubs(:find_by_full_name).with("course files/path2/bar").returns(nil)
        folder.expects(:locked=).with(true)
        folder.expects(:save)

        Importers::AttachmentImporter.process_migration(data, migration)
      end

      it "hidden_folders" do
        data = {
            hidden_folders: [
                "path1/foo",
                "path2/bar"
            ]
        }

        active_folders_association = stub()
        course.expects(:active_folders).returns(active_folders_association).twice
        folder = stub()
        active_folders_association.stubs(:find_by_full_name).with("course files/path1/foo").returns(folder)
        active_folders_association.stubs(:find_by_full_name).with("course files/path2/bar").returns(nil)
        folder.expects(:workflow_state=).with("hidden")
        folder.expects(:save)

        Importers::AttachmentImporter.process_migration(data, migration)
      end

      describe "saving import failures" do
        it "saves import failures with display name" do
          data = {
              'file_map' => {
                  'a' => {
                      id: attachment_id,
                      migration_id: migration_id,
                      display_name: "foo"
                  }
              }
          }

          error = RuntimeError.new
          ::Attachment.expects(:find_by_context_type_and_context_id_and_id).raises(error)
          migration.expects(:add_import_warning).with(I18n.t('#migration.file_type', "File"), "foo", error)

          Importers::AttachmentImporter.process_migration(data, migration)
        end

        it "saves import failures with path name" do
          data = {
              'file_map' => {
                  'a' => {
                      id: attachment_id,
                      migration_id: migration_id,
                      path_name: "bar"
                  }
              }
          }

          error = RuntimeError.new
          ::Attachment.expects(:find_by_context_type_and_context_id_and_id).raises(error)
          migration.expects(:add_import_warning).with(I18n.t('#migration.file_type', "File"), "bar", error)

          Importers::AttachmentImporter.process_migration(data, migration)
        end
      end
    end
  end
end
defmodule Pop3mail.EpopDownloader do
  alias Pop3mail.Handler

  require Logger

   @doc "Read all emails and save them to disk."
   def download(username, password, pop3_server, pop3_port, ssl, max_mails, delete, delivered, save_raw, output_dir) do
     username = to_char_list username 
     password = to_char_list password 
     pop3_server = to_char_list pop3_server
     connect_options = [{:addr, pop3_server}, {:port, pop3_port}]
     if is_nil(ssl) or ssl do
       connect_options = connect_options ++ [:ssl]
     end
     case :epop_client.connect(username, password, connect_options) do
       {:ok,    client} -> retrieve_and_store_all(client, max_mails, delete, delivered, save_raw, output_dir)
       {:error, reason} -> Logger.error reason
     end
     Logger.info "Ready."
   end

   def retrieve_and_store_all(epop_client, max_mails, delete, delivered, save_raw, output_dir) do
     try do
        {:ok, {count, size_total}} = :epop_client.stat(epop_client)
        Logger.info "#{count} messages, #{size_total} bytes total."
        count = min(count, max_mails)
        if count > 0 do
            # create inbox directory to store emails
            unless File.dir?(output_dir), do: File.mkdir! output_dir
            # loop all messages
            1..count |> Enum.map(&retrieve_and_store(epop_client, &1, delete, delivered, save_raw, output_dir))
        end
     after
        :epop_client.quit(epop_client)
     end
   end

   def retrieve_and_store(epop_client, mail_loop_counter, delete, delivered, save_raw, base_dir) do
      {:ok, mail_content} = :epop_client.retrieve(epop_client, mail_loop_counter)
      parse_process_and_store(mail_content, mail_loop_counter, delivered, save_raw, base_dir)
      if delete do
        :ok = :epop_client.delete(epop_client, mail_loop_counter)
      end
   end

   def parse_process_and_store(mail_content, mail_loop_counter, delivered, save_raw, base_dir) do
      {:message, header_list, body_char_list } = :epop_message.parse(mail_content)
      Handler.check_process_and_store(mail_content, mail_loop_counter, header_list, body_char_list, delivered, save_raw, base_dir)
   end
    
end

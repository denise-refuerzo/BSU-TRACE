import React, { useState, useEffect, useRef } from 'react';
import { Send, Lock, MessageSquare, RefreshCw, Search } from 'lucide-react';
import { fetchWithAuth } from '../api';

export default function OfficeChatHub({ userId, roleId, officeId }) {
  const [directory, setDirectory] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedDoc, setSelectedDoc] = useState(null);
  const [channels, setChannels] = useState([]);
  const [activeChannel, setActiveChannel] = useState(null);
  const [messages, setMessages] = useState([]);
  const [textInput, setTextInput] = useState('');
  const [loading, setLoading] = useState(false);
  const messageEndRef = useRef(null);

  useEffect(() => {
    fetchActiveDirectory();
  }, []);

  useEffect(() => {
    if (activeChannel) {
      fetchMessageLogs(activeChannel.roomId);
      const streamTimer = setInterval(() => fetchMessageLogs(activeChannel.roomId), 5000);
      return () => clearInterval(streamTimer);
    }
  }, [activeChannel]);

  useEffect(() => {
    messageEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const fetchActiveDirectory = async () => {
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/chat/active-documents-directory');
      const data = await res.json();
      if (res.ok) setDirectory(data);
    } catch (err) { console.error(err); }
  };

  const handleSelectDocument = async (doc) => {
    setSelectedDoc(doc);
    setActiveChannel(null);
    setMessages([]);
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/chat/document-channels/${doc.ini_id}`);
      const data = await res.json();
      if (res.ok) {
        setChannels(data);
        
        // IF USER IS A PROCESSOR, AUTOMATICALLY LOAD THEIR SPECIFIC WORKSPACE CHANNEL
        if (roleId === 2 && officeId) {
          const targetOfficeChannel = data.find(c => c.officeId === parseInt(officeId));
          if (targetOfficeChannel) {
            handleActivateChannel(doc.ini_id, targetOfficeChannel);
          }
        }
      }
    } catch (err) { console.error(err); }
  };

  const handleActivateChannel = async (docId, channel) => {
    setLoading(true);
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/chat/get-or-create-room', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ iniId: docId, officeId: channel.officeId })
      });
      const data = await res.json();
      if (res.ok) {
        setActiveChannel({ ...channel, roomId: data.roomId });
      }
    } catch (err) { console.error(err); }
    finally { setLoading(false); }
  };

  const fetchMessageLogs = async (roomId) => {
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/chat/rooms/${roomId}/messages`);
      const data = await res.json();
      if (res.ok) setMessages(data);
    } catch (err) { console.error(err); }
  };

  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!textInput.trim() || !activeChannel) return;

    try {
      const res = await fetchWithAuth('http://localhost:5000/api/chat/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ roomId: activeChannel.roomId, messageText: textInput })
      });
      if (res.ok) {
        setTextInput('');
        fetchMessageLogs(activeChannel.roomId);
      }
    } catch (err) { console.error(err); }
  };

  // FILTER DIRECTORY ENTRIES DYNAMICALLY BY TITLE SEARCH INPUT
  const filteredDirectory = directory.filter(doc => 
    doc.title.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // DETECT IF AN ACTIVE AD-HOC DETOUR IS EXTANT ON THE CURRENT LIFECYCLE
  const adHocDetourChannel = roleId === 2 && channels.find(c => c.officeId !== parseInt(officeId));

  return (
    <div className="max-w-6xl mx-auto h-[calc(100vh-12rem)] border border-neutral-200 bg-white rounded-2xl shadow-sm flex overflow-hidden text-left animate-in fade-in duration-150">
      
      {/* LEFT COLUMN: SYSTEM DATA DIRECTORIES (With search integration) */}
      <div className="w-80 border-r border-neutral-100 flex flex-col bg-neutral-50/30 flex-shrink-0">
        <div className="p-4 border-b bg-white space-y-3">
          <div className="flex justify-between items-center">
            <h4 className="text-xs font-black uppercase tracking-wider text-neutral-400">Document References</h4>
            <button onClick={fetchActiveDirectory} className="p-1 hover:bg-neutral-100 rounded text-neutral-500"><RefreshCw size={14} /></button>
          </div>
          
          {/* INTERACTIVE SEARCH BAR COMPONENT */}
          <div className="relative">
            <Search className="absolute left-2.5 top-2 text-neutral-400" size={13} />
            <input 
              type="text" 
              placeholder="Search by file name..." 
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              className="w-full pl-8 pr-3 py-1 text-[11px] border border-neutral-300 rounded-lg bg-neutral-50 outline-none focus:ring-1 focus:ring-red-700 font-medium" 
            />
          </div>
        </div>
        
        <div className="flex-1 overflow-y-auto divide-y divide-neutral-100 p-2 space-y-1">
          {filteredDirectory.map(doc => (
            <button key={doc.ini_id} onClick={() => handleSelectDocument(doc)}
                    className={`w-full p-3 text-left rounded-xl transition-all flex flex-col gap-1 relative border ${
                      selectedDoc?.ini_id === doc.ini_id 
                        ? 'bg-red-50/40 border-red-200/50' 
                        : doc.hasAnyChat 
                          ? 'bg-amber-50/40 border-amber-200/40 hover:bg-amber-50/60' 
                          : 'hover:bg-neutral-100/60 border-transparent'
                    }`}>
              <div className="flex items-center justify-between w-full pr-2">
                <p className="text-xs font-black text-neutral-900 line-clamp-1">{doc.title}</p>
                {doc.hasAnyChat && <span className="w-2 h-2 bg-amber-500 rounded-full flex-shrink-0 ml-1"></span>}
              </div>
              <span className="text-[10px] font-mono font-bold text-neutral-400">ID: {doc.ini_id}</span>
            </button>
          ))}
          {filteredDirectory.length === 0 && <p className="text-center text-xs text-neutral-400 font-bold mt-8">No matching records.</p>}
        </div>
      </div>

      {/* CENTER COLUMN: RENDERED FOR ORIGINATORS (ROLE 1) ONLY */}
      {roleId === 1 && selectedDoc && (
        <div className="w-64 border-r border-neutral-100 flex flex-col flex-shrink-0 animate-in slide-in-from-left-1 duration-150">
          <div className="p-4 border-b bg-white">
            <h4 className="text-xs font-black uppercase tracking-wider text-neutral-400">Station Channels</h4>
          </div>
          <div className="flex-1 overflow-y-auto p-2 space-y-1 bg-neutral-50/10">
            {channels.map(chan => (
              <button key={chan.officeId} onClick={() => handleActivateChannel(selectedDoc.ini_id, chan)}
                      className={`w-full p-3 text-left rounded-xl border transition-all flex flex-col gap-1 relative ${
                        activeChannel?.officeId === chan.officeId 
                          ? 'bg-neutral-900 border-neutral-900 text-white shadow-xs' 
                          : chan.hasChat 
                            ? 'bg-amber-50 border-amber-200 text-neutral-800 hover:bg-amber-100/70' 
                            : 'bg-white hover:bg-neutral-50 border-neutral-200 text-neutral-800'
                      }`}>
                <div className="flex items-center justify-between w-full">
                  <p className="text-xs font-bold truncate pr-2">{chan.officeName}</p>
                  {chan.hasChat && activeChannel?.officeId !== chan.officeId && (
                    <span className="w-1.5 h-1.5 bg-amber-500 rounded-full flex-shrink-0"></span>
                  )}
                </div>
                <span className={`text-[9px] font-black uppercase tracking-wider ${activeChannel?.officeId === chan.officeId ? 'text-red-400' : chan.isLocked ? 'text-neutral-400' : 'text-green-600'}`}>
                  {chan.statusMessage}
                </span>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* RIGHT COLUMN: INTERACTIVE MESSENGER WORKSPACE CONTEXT */}
      <div className="flex-1 flex flex-col bg-white relative">
        {activeChannel ? (
          <>
            <div className="p-4 border-b border-neutral-100 bg-[#FDFBF9] flex flex-col gap-3">
              <div className="flex justify-between items-start">
                <div>
                  <h4 className="text-sm font-black text-neutral-900">{activeChannel.officeName}</h4>
                  <p className="text-[10px] text-neutral-400 font-medium mt-0.5">Subject: <span className="text-red-800 font-bold">{selectedDoc.title}</span></p>
                </div>
              </div>

              {/* CROSS-OFFICE AD-HOC VERIFICATION CHAT SUB-TABS (Only visible to processors under detour states) */}
              {roleId === 2 && adHocDetourChannel && (
                <div className="flex bg-neutral-100 p-1 rounded-lg text-[11px] font-bold w-max max-w-full">
                  <button 
                    onClick={() => handleSelectDocument(selectedDoc)}
                    className={`px-3 py-1.5 rounded-md transition-all ${activeChannel.officeId === parseInt(officeId) ? 'bg-white text-neutral-900 shadow-xs' : 'text-neutral-500 hover:text-neutral-700'}`}
                  >
                    💬 Chat with Originator
                  </button>
                  <button 
                    onClick={() => handleActivateChannel(selectedDoc.ini_id, adHocDetourChannel)}
                    className={`px-3 py-1.5 rounded-md transition-all ${activeChannel.officeId !== parseInt(officeId) ? 'bg-white text-neutral-900 shadow-xs' : 'text-neutral-500 hover:text-neutral-700'}`}
                  >
                    🔄 Detour Office Update ({adHocDetourChannel.officeName.split(' ')[0]})
                  </button>
                </div>
              )}
            </div>

            <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-neutral-50/30">
              {messages.map(msg => {
                const isMe = msg.sender_id === parseInt(userId);
                return (
                  <div key={msg.message_id} className={`flex flex-col max-w-[70%] ${isMe ? 'ml-auto items-end' : 'mr-auto items-start'}`}>
                    <span className="text-[9px] font-black text-neutral-400 uppercase tracking-tight mb-1">{msg.sender_name} ({msg.role_name})</span>
                    <div className={`p-3 rounded-2xl text-xs font-medium leading-relaxed shadow-2xs ${isMe ? 'bg-red-800 text-white rounded-tr-none' : 'bg-white border text-neutral-800 rounded-tl-none'}`}>
                      {msg.message_text}
                    </div>
                  </div>
                );
              })}
              <div ref={messageEndRef} />
            </div>

            {activeChannel.isLocked ? (
              <div className="p-4 border-t border-neutral-200 bg-neutral-50 flex items-center justify-center gap-2 text-neutral-500 font-bold text-xs select-none">
                <Lock size={14} className="text-neutral-400" /> {activeChannel.statusMessage}
              </div>
            ) : (
              <form onSubmit={handleSendMessage} className="p-4 border-t border-neutral-100 bg-white flex gap-2">
                <input type="text" placeholder="Type your message..." value={textInput} onChange={e => setTextInput(e.target.value)}
                       className="flex-1 border px-4 py-2 text-xs rounded-xl outline-none focus:ring-1 focus:ring-red-700 bg-neutral-50 font-medium" />
                <button type="submit" disabled={!textInput.trim()} className="p-2.5 bg-red-800 hover:bg-red-900 text-white rounded-xl shadow-xs transition-colors disabled:opacity-40"><Send size={14} /></button>
              </form>
            )}
          </>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center text-neutral-400 gap-2 select-none">
            <MessageSquare size={36} className="text-neutral-200" />
            <p className="text-xs font-bold">Select a reference file to establish conversation metrics.</p>
          </div>
        )}
      </div>

    </div>
  );
}